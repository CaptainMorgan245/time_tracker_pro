// lib/database_helper.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // <-- NEW: Import for platform detection and file operations
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart'; // <-- NEW: Import for finding Documents directory
import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/models.dart';
//import 'package:time_tracker_pro/models/project_summary.dart';

// ============================================================================
// |                  FINAL, STABLE V2 DATABASE HELPER                      |
// ============================================================================

class DatabaseHelperV2 {
  DatabaseHelperV2._privateConstructor();
  static final DatabaseHelperV2 instance = DatabaseHelperV2._privateConstructor();

  static Database? _database;
  static Completer<Database>? _dbCompleter;
  static const String _dbName = 'time_tracker_pro.db';
  static const int _dbVersion = 1;

  final ValueNotifier<int> databaseNotifier = ValueNotifier(0);

  void _notifyListeners() {
    databaseNotifier.value++;
  }

  void notifyDatabaseChanged() {
    _notifyListeners();
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    _dbCompleter = Completer<Database>();

    try {
      _database = await _initDatabase();
      _dbCompleter!.complete(_database);
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null;
    }

    return _dbCompleter!.future;
  }

  // == MODIFIED: THIS FUNCTION NOW HANDLES DESKTOP vs MOBILE PATHS ==
  Future<String> _getDatabasePath() async {
    // Check if running on a desktop platform
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Use a stable location like the Documents folder for desktop
      final docDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${docDir.path}/TimeTrackerPro');

      // Create the subdirectory if it doesn't exist
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      return '${dataDir.path}/$_dbName';
    } else {
      // Use the default path for mobile (Android/iOS)
      final path = await getDatabasesPath();
      return '$path/$_dbName';
    }
  }
  // == END MODIFICATION ==

  Future<Database> _initDatabase() async {
    debugPrint("[DB_V2] Initializing database...");
    // MODIFIED: Use the new function to get the correct path
    final dbPath = await _getDatabasePath();
    debugPrint("[DB_V2] Database path: $dbPath");

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('[DB_V2] Upgrading database from version $oldVersion to $newVersion...');
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB_V2] _onCreate called. Creating all tables for a fresh install...');

    await db.transaction((txn) async {
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY, employee_number_prefix TEXT, next_employee_number INTEGER, vehicle_designations TEXT, vendors TEXT, company_hourly_rate REAL, burden_rate REAL, time_rounding_interval INTEGER, auto_backup_reminder_frequency INTEGER, app_runs_since_backup INTEGER, measurement_system TEXT, default_report_months INTEGER
          )
        ''');
      await txn.execute('''
          INSERT INTO settings(id, next_employee_number, company_hourly_rate, burden_rate, time_rounding_interval, auto_backup_reminder_frequency, app_runs_since_backup, default_report_months)
          VALUES(1, 1, 0.0, 0.0, 15, 10, 0, 3)
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, contact_person TEXT, phone_number TEXT
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_name TEXT NOT NULL, client_id INTEGER NOT NULL, location TEXT, pricing_model TEXT DEFAULT 'hourly', is_completed INTEGER NOT NULL DEFAULT 0, completion_date TEXT, is_internal INTEGER NOT NULL DEFAULT 0, billed_hourly_rate REAL, FOREIGN KEY (client_id) REFERENCES clients(id), UNIQUE(project_name, client_id)
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, standard_rate REAL NOT NULL DEFAULT 0.0
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT, employee_number TEXT UNIQUE, name TEXT NOT NULL, title_id INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (title_id) REFERENCES roles(id)
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS time_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER, employee_id INTEGER, start_time TEXT NOT NULL, end_time TEXT, paused_duration REAL DEFAULT 0.0, final_billed_duration_seconds REAL, is_paused INTEGER DEFAULT 0, pause_start_time TEXT, is_deleted INTEGER DEFAULT 0, work_details TEXT, FOREIGN KEY (project_id) REFERENCES projects(id), FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS materials (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER, item_name TEXT NOT NULL, cost REAL NOT NULL, purchase_date TEXT, description TEXT, is_deleted INTEGER DEFAULT 0, expense_category TEXT, unit TEXT, quantity REAL, base_quantity REAL, odometer_reading REAL, is_company_expense INTEGER DEFAULT 0, vehicle_designation TEXT, vendor_or_subtrade TEXT, FOREIGN KEY (project_id) REFERENCES projects(id)
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS expense_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL
          )
        ''');
    });
    debugPrint('[DB_V2] All tables created and default settings inserted successfully.');
  }

  Future<List<AllRecordViewModel>> getAllRecordsV2() async {
    final db = await database;
    final List<AllRecordViewModel> allRecords = [];
    final timeQuery = '''
      SELECT t.id, t.start_time, t.work_details, t.final_billed_duration_seconds, p.project_name, c.name as client_name
      FROM time_entries t
      JOIN projects p ON t.project_id = p.id
      JOIN clients c ON p.client_id = c.id
      WHERE t.is_deleted = 0 AND t.start_time IS NOT NULL
    ''';
    final timeEntryMaps = await db.rawQuery(timeQuery);
    for (var map in timeEntryMaps) {
      final projectName = map['project_name'] as String? ?? 'Unknown Project';
      final clientName = map['client_name'] as String? ?? 'Unknown Client';
      allRecords.add(AllRecordViewModel(id: map['id'] as int, type: RecordType.time, date: DateTime.parse(map['start_time'] as String), description: map['work_details'] as String? ?? 'No Details', value: (map['final_billed_duration_seconds'] as num? ?? 0.0) / 3600.0, categoryOrProject: '$clientName - $projectName',));
    }
    final materialQuery = '''
      SELECT m.id, m.purchase_date, m.item_name, m.cost, m.expense_category, p.project_name
      FROM materials m
      JOIN projects p ON m.project_id = p.id
      WHERE m.is_deleted = 0 AND m.purchase_date IS NOT NULL
    ''';
    final materialMaps = await db.rawQuery(materialQuery);
    for (var map in materialMaps) {
      final category = map['expense_category'] as String?;
      final projectName = map['project_name'] as String?;
      String displayCategory = category ?? projectName ?? 'Uncategorized';
      allRecords.add(AllRecordViewModel(id: map['id'] as int, type: RecordType.expense, date: DateTime.parse(map['purchase_date'] as String), description: map['item_name'] as String? ?? 'Unnamed Item', value: (map['cost'] as num? ?? 0.0).toDouble(), categoryOrProject: displayCategory,));
    }
    allRecords.sort((a, b) => b.id.compareTo(a.id));
    return allRecords;
  }

  Future<List<ExpenseCategory>> getExpenseCategoriesV2() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expense_categories', orderBy: 'name');
    return List.generate(maps.length, (i) => ExpenseCategory.fromMap(maps[i]));
  }

  Future<List<JobMaterials>> getRecentMaterialsV2() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('materials', where: 'is_deleted = 0', orderBy: 'purchase_date DESC', limit: 100,);
    return List.generate(maps.length, (i) => JobMaterials.fromMap(maps[i]));
  }

  Future<void> addMaterialV2(JobMaterials expense) async {
    final db = await database;
    await db.insert('materials', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyListeners();
  }

  Future<void> updateMaterialV2(JobMaterials expense) async {
    final db = await database;
    await db.update('materials', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
    _notifyListeners();
  }

  Future<void> addExpenseCategoryV2(ExpenseCategory category) async {
    final db = await database;
    await db.insert('expense_categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyListeners();
  }

  Future<void> updateExpenseCategoryV2(ExpenseCategory category) async {
    final db = await database;
    await db.update('expense_categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
    _notifyListeners();
  }

  Future<void> deleteRecordV2({required int id, required String fromTable}) async {
    final db = await database;
    if (fromTable == 'time_entries' || fromTable == 'materials') {
      await db.update(fromTable, {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.delete(fromTable, where: 'id = ?', whereArgs: [id]);
    }
    _notifyListeners();
  }

  // ============================================================================
  // |                      EXPORT/IMPORT METHODS                             |
  // ============================================================================

  Future<String> exportDatabaseToJson() async {
    debugPrint('[DB_V2] ===== STARTING EXPORT =====');
    final db = await database;
    debugPrint('[DB_V2] Database obtained: ${db.path}');
    debugPrint('[DB_V2] Database isOpen: ${db.isOpen}');

    final Map<String, List<Map<String, dynamic>>> allTables = {};

    const List<String> tableNames = [
      'settings',
      'clients',
      'projects',
      'roles',
      'employees',
      'time_entries',
      'materials',
      'expense_categories'
    ];

    for (String tableName in tableNames) {
      final List<Map<String, dynamic>> tableRows = await db.query(tableName);
      debugPrint('[DB_V2] Table "$tableName" has ${tableRows.length} rows');
      allTables[tableName] = tableRows;
    }

    final Map<String, dynamic> exportData = {
      'export_format_version': 1,
      'export_timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      'database_version': _dbVersion,
      'tables': allTables,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    debugPrint('[DB_V2] Export JSON length: ${jsonString.length} characters');
    debugPrint('[DB_V2] ===== EXPORT COMPLETE =====');
    return jsonString;
  }

  Future<void> importDatabaseFromJson(String jsonString) async {
    final db = await database;

    const List<String> deletionOrder = [
      'time_entries',
      'materials',
      'projects',
      'employees',
      'clients',
      'roles',
      'expense_categories',
      'settings'
    ];

    final List<String> insertionOrder = deletionOrder.reversed.toList();

    final Map<String, dynamic> importData = json.decode(jsonString);
    final Map<String, dynamic> tables = importData['tables'];

    await db.transaction((txn) async {
      for (String tableName in deletionOrder) {
        await txn.delete(tableName);
      }

      for (String tableName in insertionOrder) {
        if (tables.containsKey(tableName)) {
          List<dynamic> rows = tables[tableName];
          for (var row in rows) {
            row.removeWhere((key, value) => value == null);
            await txn.insert(tableName, row as Map<String, dynamic>);
          }
        }
      }
    });

    notifyDatabaseChanged();
    debugPrint('[DB_V2] Import successful. Database has been restored from backup.');
  }

  // MODIFIED: deleteAllData now also uses the platform-aware path getter
  Future<void> deleteAllData() async {
    debugPrint('[DB_V2] ⚠️ WARNING: deleteAllData() called!');
    debugPrint('[DB_V2] Stack trace: ${StackTrace.current}');

    final dbPath = await _getDatabasePath(); // <-- Uses the corrected path

    if (_database?.isOpen == true) {
      await _database!.close();
      _database = null;
      _dbCompleter = null;
    }

    try {
      await deleteDatabase(dbPath);
      debugPrint('[DB_V2] Database file at $dbPath deleted successfully.');
    } catch (e) {
      debugPrint('[DB_V2] Error deleting database file: $e');
    }

    notifyDatabaseChanged();
    debugPrint('[DB_V2] Database has been reset. It will re-initialize on next use.');
  }
}
