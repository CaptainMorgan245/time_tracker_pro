import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Settings,
  Clients,
  Projects,
  Roles,
  Employees,
  CostCodes,
  ExpenseCategories,
  Invoices,
  TimeEntries,
  Materials,
  CompanySettingsTable,
  WorkerPayments,
])
class AppDatabase extends _$AppDatabase {

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Insert default settings row
      await into(settings).insert(SettingsCompanion.insert(
        id: const Value(1),
        nextEmployeeNumber: const Value(1),
        companyHourlyRate: const Value(0.0),
        burdenRate: const Value(0.0),
        timeRoundingInterval: const Value(15),
        autoBackupReminderFrequency: const Value(10),
        appRunsSinceBackup: const Value(0),
        defaultReportMonths: const Value(3),
        expenseMarkupPercentage: const Value(0.0),
        setupCompleted: const Value(0),
      ));
      // Insert default company_settings row
      await into(companySettingsTable).insert(
        CompanySettingsTableCompanion.insert(id: const Value(1)),
      );
      await customInsert(
        "INSERT INTO clients (name, is_active) VALUES ('Company Expenses', 1)",
        variables: [],
      );
      await customInsert(
        '''INSERT INTO projects
          (project_name, client_id, pricing_model, is_completed, is_internal,
           expense_markup_percentage, tax_rate)
          VALUES ('Internal Company Project',
            (SELECT id FROM clients WHERE name = 'Company Expenses'),
            'hourly', 0, 1, 15.0, 5.0)''',
        variables: [],
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 17) {
        // Use custom statements for migration to avoid issues with un-synced generated code
        await customStatement('ALTER TABLE company_settings ADD COLUMN postal_code_label TEXT DEFAULT "Postal Code";');
        await customStatement('ALTER TABLE company_settings ADD COLUMN region_label TEXT DEFAULT "Province";');
        await customStatement('ALTER TABLE company_settings ADD COLUMN country TEXT DEFAULT "Canada";');
      }
      if (from < 18) {
        await customStatement('ALTER TABLE projects ADD COLUMN street_address TEXT;');
        await customStatement('ALTER TABLE projects ADD COLUMN region TEXT;');
        await customStatement('ALTER TABLE projects ADD COLUMN postal_code TEXT;');
      }
      if (from < 19) {
        await customStatement('ALTER TABLE projects RENAME COLUMN location TO city;');
        await customStatement('ALTER TABLE invoices ADD COLUMN work_description TEXT;');
      }
      if (from < 20) {
        await customStatement(
          "INSERT OR IGNORE INTO clients (name, is_active) VALUES ('Company Expenses', 1)",
        );
        await customStatement(
          '''INSERT INTO projects
            (project_name, client_id, pricing_model, is_completed, is_internal,
             expense_markup_percentage, tax_rate)
            SELECT 'Internal Company Project',
              (SELECT id FROM clients WHERE name = 'Company Expenses'),
              'hourly', 0, 1, 15.0, 5.0
            WHERE NOT EXISTS (SELECT 1 FROM projects WHERE is_internal = 1)''',
        );
      }
    },
  );

  // =========================================================================
  // Singleton wiring — matches AppDatabase public interface exactly
  // =========================================================================

  static final AppDatabase _instance = AppDatabase();
  static AppDatabase get instance => _instance;

  final ValueNotifier<int> databaseNotifier = ValueNotifier(0);

  void _notifyListeners() => databaseNotifier.value++;
  void notifyDatabaseChanged() => _notifyListeners();

  // =========================================================================
  // DASHBOARD
  // =========================================================================

  Future<List<AllRecordViewModel>> getDashboardTimeEntries() async {
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();

    final rows = await customSelect('''
      SELECT
        t.id, t.start_time, t.work_details, t.final_billed_duration_seconds,
        t.employee_id, t.cost_code_id,
        p.project_name, c.name as client_name,
        cc.name as cost_code_name
      FROM time_entries t
      JOIN projects p ON t.project_id = p.id
      JOIN clients c ON p.client_id = c.id
      LEFT JOIN cost_codes cc ON t.cost_code_id = cc.id
      WHERE t.is_deleted = 0
        AND p.is_completed = 0
        AND t.start_time >= ?
      ORDER BY t.start_time DESC
    ''', variables: [Variable.withString(sevenDaysAgo)]).get();

    return rows.map((row) {
      final data = row.data;
      return AllRecordViewModel(
        id: data['id'] as int,
        type: RecordType.time,
        date: DateTime.parse(data['start_time'] as String),
        description: data['work_details'] as String? ?? 'No Details',
        value: (data['final_billed_duration_seconds'] as num? ?? 0.0) / 3600.0,
        categoryOrProject:
            '${data['client_name'] as String? ?? 'Unknown Client'} - '
            '${data['project_name'] as String? ?? 'Unknown Project'}',
        employeeId: data['employee_id'] as int?,
        costCodeId: data['cost_code_id'] as int?,
        costCodeName: data['cost_code_name'] as String?,
      );
    }).toList();
  }

  // =========================================================================
  // ALL RECORDS
  // =========================================================================

  Future<List<AllRecordViewModel>> getAllRecordsV2() async {
    final List<AllRecordViewModel> allRecords = [];

    final timeRows = await customSelect('''
      SELECT t.id, t.start_time, t.work_details, t.final_billed_duration_seconds,
             p.project_name, c.name as client_name
      FROM time_entries t
      JOIN projects p ON t.project_id = p.id
      JOIN clients c ON p.client_id = c.id
      WHERE t.is_deleted = 0 AND t.start_time IS NOT NULL
    ''').get();

    for (final row in timeRows) {
      final data = row.data;
      allRecords.add(AllRecordViewModel(
        id: data['id'] as int,
        type: RecordType.time,
        date: DateTime.parse(data['start_time'] as String),
        description: data['work_details'] as String? ?? 'No Details',
        value: (data['final_billed_duration_seconds'] as num? ?? 0.0) / 3600.0,
        categoryOrProject:
            '${data['client_name'] as String? ?? 'Unknown Client'} - '
            '${data['project_name'] as String? ?? 'Unknown Project'}',
      ));
    }

    final matRows = await customSelect('''
      SELECT m.id, m.purchase_date, m.item_name, m.cost, m.expense_category,
             p.project_name
      FROM materials m
      JOIN projects p ON m.project_id = p.id
      WHERE m.is_deleted = 0 AND m.purchase_date IS NOT NULL
    ''').get();

    for (final row in matRows) {
      final data = row.data;
      allRecords.add(AllRecordViewModel(
        id: data['id'] as int,
        type: RecordType.expense,
        date: DateTime.parse(data['purchase_date'] as String),
        description: data['item_name'] as String? ?? 'Unnamed Item',
        value: (data['cost'] as num? ?? 0.0).toDouble(),
        categoryOrProject: data['expense_category'] as String? ??
            data['project_name'] as String? ??
            'Uncategorized',
      ));
    }

    allRecords.sort((a, b) => b.id.compareTo(a.id));
    return allRecords;
  }

  // =========================================================================
  // COST ENTRY
  // =========================================================================

  Future<List<JobMaterials>> getCostEntryMaterials(
    bool showCompleted,
    List<Project> allProjects, {
    int? selectedProjectId,
  }) async {
    List<int> projectIds;
    if (selectedProjectId != null) {
      projectIds = [selectedProjectId];
    } else {
      projectIds = showCompleted
          ? allProjects
              .where((p) => p.isCompleted && p.id != null)
              .map((p) => p.id!)
              .toList()
          : allProjects
              .where((p) => (!p.isCompleted || p.isInternal) && p.id != null)
              .map((p) => p.id!)
              .toList();
    }

    if (projectIds.isEmpty) return [];

    final placeholders = projectIds.map((_) => '?').join(',');
    final rows = await customSelect(
      'SELECT * FROM materials WHERE project_id IN ($placeholders) '
      'AND is_deleted = 0 ORDER BY purchase_date DESC',
      variables: projectIds.map((id) => Variable.withInt(id)).toList(),
    ).get();

    return rows.map((r) => JobMaterials.fromMap(r.data)).toList();
  }

  Future<List<JobMaterials>> searchMaterialsByAmount(String amountPrefix) async {
    final rows = await customSelect(
      'SELECT * FROM materials WHERE is_deleted = 0 ORDER BY purchase_date DESC',
    ).get();

    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final normalizedPrefix = amountPrefix.replaceAll(RegExp(r'[,\$]'), '');
    return rows
        .map((row) => JobMaterials.fromMap(row.data))
        .where((record) {
          final formatted = formatter.format(record.cost).replaceAll(RegExp(r'[,\$]'), '');
          return formatted.startsWith(normalizedPrefix);
        })
        .toList();
  }

  // =========================================================================
  // EXPENSE CATEGORIES
  // =========================================================================

  Future<List<ExpenseCategory>> getExpenseCategoriesV2() async {
    final rows = await select(expenseCategories)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return (await rows.get())
        .map((r) => ExpenseCategory(id: r.id, name: r.name))
        .toList();
  }

  Future<void> addExpenseCategoryV2(ExpenseCategory category) async {
    into(expenseCategories).insert(
      ExpenseCategoriesCompanion.insert(name: category.name),
      mode: InsertMode.insertOrReplace,
    );
    _notifyListeners();
  }

  Future<void> updateExpenseCategoryV2(ExpenseCategory category) async {
    await (update(expenseCategories)
          ..where((t) => t.id.equals(category.id!)))
        .write(ExpenseCategoriesCompanion(name: Value(category.name)));
    _notifyListeners();
  }

  // =========================================================================
  // MATERIALS
  // =========================================================================

  Future<List<JobMaterials>> getRecentMaterialsV2() async {
    final rows = await customSelect(
      'SELECT * FROM materials WHERE is_deleted = 0 '
      'ORDER BY purchase_date DESC LIMIT 100',
    ).get();
    return rows.map((r) => JobMaterials.fromMap(r.data)).toList();
  }

  Future<void> addMaterialV2(JobMaterials expense) async {
    await into(materials).insert(
      _materialsToCompanion(expense),
      mode: InsertMode.insertOrReplace,
    );
    _notifyListeners();
  }

  Future<void> updateMaterialV2(JobMaterials expense) async {
    await (update(materials)..where((t) => t.id.equals(expense.id!)))
        .write(_materialsToCompanion(expense));
    _notifyListeners();
  }

  MaterialsCompanion _materialsToCompanion(JobMaterials m) {
    return MaterialsCompanion(
      id: m.id != null ? Value(m.id!) : const Value.absent(),
      projectId: Value(m.projectId),
      itemName: Value(m.itemName),
      cost: Value(m.cost),
      purchaseDate: Value(m.purchaseDate.toIso8601String()),
      description: Value(m.description),
      isDeleted: Value(m.isDeleted ? 1 : 0),
      expenseCategory: Value(m.expenseCategory),
      unit: Value(m.unit),
      quantity: Value(m.quantity),
      baseQuantity: Value(m.baseQuantity),
      odometerReading: Value(m.odometerReading),
      isCompanyExpense: Value(m.isCompanyExpense ? 1 : 0),
      vehicleDesignation: Value(m.vehicleDesignation),
      vendorOrSubtrade: Value(m.vendorOrSubtrade),
      costCodeId: Value(m.costCodeId),
      isBilled: Value(m.isBilled ? 1 : 0),
      invoiceId: Value(m.invoiceId),
    );
  }

  // =========================================================================
  // PROJECT RECORDS
  // =========================================================================

  Future<List<dynamic>> getProjectRecordsV2(
      bool showCompleted, List<Project> allProjects) async {
    final projectIds = showCompleted
        ? allProjects.where((p) => p.isCompleted).map((p) => p.id).toList()
        : allProjects
            .where((p) => !p.isCompleted || p.isInternal)
            .map((p) => p.id)
            .toList();

    if (projectIds.isEmpty) return [];

    final placeholders = projectIds.map((_) => '?').join(',');
    final vars = projectIds.map((id) => Variable.withInt(id!)).toList();

    final teRows = await customSelect(
      'SELECT * FROM time_entries WHERE project_id IN ($placeholders) '
      'AND is_deleted = 0 ORDER BY start_time DESC LIMIT 50',
      variables: vars,
    ).get();

    final matRows = await customSelect(
      'SELECT * FROM materials WHERE project_id IN ($placeholders) '
      'AND is_deleted = 0 ORDER BY purchase_date DESC LIMIT 50',
      variables: vars,
    ).get();

    return [
      ...teRows.map((r) => TimeEntry.fromMap(r.data)),
      ...matRows.map((r) => JobMaterials.fromMap(r.data)),
    ];
  }

  // =========================================================================
  // DELETE (soft delete)
  // =========================================================================

  Future<void> deleteRecordV2(
      {required int id, required String fromTable}) async {
    if (fromTable == 'time_entries' || fromTable == 'materials') {
      await customUpdate(
        'UPDATE $fromTable SET is_deleted = 1 WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: fromTable == 'time_entries'
            ? {timeEntries}
            : {materials},
      );
    } else {
      await customUpdate(
        'DELETE FROM $fromTable WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {},
      );
    }
    _notifyListeners();
  }

  // =========================================================================
  // COMPANY SETTINGS
  // =========================================================================

  Future<CompanySettings> getCompanySettings() async {
    final rows = await customSelect(
      'SELECT * FROM company_settings WHERE id = 1',
    ).get();
    return rows.isNotEmpty
        ? CompanySettings.fromMap(rows.first.data)
        : CompanySettings();
  }

  Future<void> updateCompanySettings(CompanySettings s) async {
    await customUpdate(
      '''UPDATE company_settings SET
        company_name = ?, company_address = ?, company_city = ?,
        company_province = ?, company_postal_code = ?, company_phone = ?,
        company_email = ?, default_tax1_name = ?, default_tax1_rate = ?,
        default_tax1_registration_number = ?, default_tax2_name = ?,
        default_tax2_rate = ?, default_tax2_registration_number = ?,
        default_terms = ?, tax_rate = ?, postal_code_label = ?, 
        region_label = ?, country = ?
      WHERE id = 1''',
      variables: [
        Variable.withString(s.companyName ?? ''),
        Variable.withString(s.companyAddress ?? ''),
        Variable.withString(s.companyCity ?? ''),
        Variable.withString(s.companyProvince ?? ''),
        Variable.withString(s.companyPostalCode ?? ''),
        Variable.withString(s.companyPhone ?? ''),
        Variable.withString(s.companyEmail ?? ''),
        Variable.withString(s.defaultTax1Name),
        Variable.withReal(s.defaultTax1Rate),
        Variable.withString(s.defaultTax1RegistrationNumber ?? ''),
        Variable.withString(s.defaultTax2Name ?? ''),
        Variable.withReal(s.defaultTax2Rate ?? 0),
        Variable.withString(s.defaultTax2RegistrationNumber ?? ''),
        Variable.withString(s.defaultTerms),
        Variable.withReal(s.taxRate),
        Variable.withString(s.postalCodeLabel),
        Variable.withString(s.regionLabel),
        Variable.withString(s.country),
      ],
      updates: {companySettingsTable},
    );
    notifyDatabaseChanged();
  }

  // =========================================================================
  // WORKER PAYMENTS
  // =========================================================================

  Future<void> updateWorkerPayment(WorkerPayment payment) async {
    await customUpdate(
      '''UPDATE worker_payments SET employee_id=?, payment_date=?,
         amount=?, note=?, created_at=? WHERE id=?''',
      variables: [
        Variable.withInt(payment.employeeId),
        Variable.withString(payment.paymentDate.toIso8601String()),
        Variable.withReal(payment.amount),
        Variable.withString(payment.note ?? ''),
        Variable.withString(payment.createdAt.toIso8601String()),
        Variable.withInt(payment.id!),
      ],
      updates: {workerPayments},
    );
    notifyDatabaseChanged();
  }

  Future<void> deleteWorkerPayment(int id) async {
    await customUpdate(
      'DELETE FROM worker_payments WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {workerPayments},
    );
    notifyDatabaseChanged();
  }

  // =========================================================================
  // EXPORT / IMPORT
  // =========================================================================

  Future<String> exportDatabaseToJson() async {
    const tableNames = [
      'settings', 'clients', 'projects', 'roles', 'employees',
      'time_entries', 'materials', 'expense_categories', 'cost_codes',
      'invoices', 'company_settings', 'worker_payments',
    ];

    final Map<String, List<Map<String, dynamic>>> allTables = {};
    for (final name in tableNames) {
      final rows =
          await customSelect('SELECT * FROM $name').get();
      allTables[name] = rows.map((r) => r.data).toList();
    }

    return const JsonEncoder.withIndent('  ').convert({
      'export_format_version': 1,
      'export_timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      'database_version': schemaVersion,
      'tables': allTables,
    });
  }

  Future<void> importDatabaseFromJson(String jsonString) async {
    const deletionOrder = [
      'time_entries', 'materials', 'worker_payments', 'employees',
      'projects', 'clients', 'roles', 'expense_categories', 'cost_codes',
      'invoices', 'company_settings', 'settings',
    ];

    await transaction(() async {
      for (final name in deletionOrder) {
        await customStatement('DELETE FROM $name');
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final tables = data['tables'] as Map<String, dynamic>;

      for (final name in tables.keys) {
        final rows = tables[name] as List<dynamic>;
        for (final row in rows) {
          final map = row as Map<String, dynamic>;
          final cols = map.keys.join(', ');
          final placeholders = map.keys.map((_) => '?').join(', ');
          await customInsert(
            'INSERT OR REPLACE INTO $name ($cols) VALUES ($placeholders)',
            variables: map.values
                .map((v) => v == null
                    ? const Variable(null)
                    : Variable(v))
                .toList(),
          );
        }
      }
    });

    _notifyListeners();
  }

  Future<void> deleteAllData() async {
    const tableNames = [
      'time_entries', 'materials', 'worker_payments', 'employees',
      'projects', 'clients', 'roles', 'expense_categories', 'cost_codes',
      'invoices', 'company_settings', 'settings',
    ];

    await transaction(() async {
      for (final name in tableNames) {
        await customStatement('DELETE FROM $name');
      }
    });

    // Re-insert defaults
    await customInsert(
      '''INSERT INTO settings(id, next_employee_number, company_hourly_rate,
         burden_rate, time_rounding_interval, auto_backup_reminder_frequency,
         app_runs_since_backup, default_report_months, expense_markup_percentage,
         setup_completed) VALUES(1,1,0.0,0.0,15,10,0,3,0.0,0)''',
      variables: [],
    );
    await customInsert(
      'INSERT INTO company_settings(id) VALUES(1)',
      variables: [],
    );

    _notifyListeners();
  }

  Future<Map<String, int?>> getInternalRecordIds() async {
    final clientRows = await customSelect(
      "SELECT id FROM clients WHERE name = 'Company Expenses' LIMIT 1",
    ).get();
    final projectRows = await customSelect(
      'SELECT id FROM projects WHERE is_internal = 1 LIMIT 1',
    ).get();
    return {
      'companyClientId': clientRows.isNotEmpty ? clientRows.first.data['id'] as int : null,
      'internalProjectId': projectRows.isNotEmpty ? projectRows.first.data['id'] as int : null,
    };
  }
}

// =========================================================================
// Database connection — handles Android, iOS, desktop, and web
// =========================================================================

QueryExecutor _openConnection() {
  return driftDatabase(name: 'time_tracker_pro');
}
