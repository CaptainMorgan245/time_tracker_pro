import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/invoice.dart';
import 'package:sqflite/sqflite.dart';

class InvoiceRepository {
  final _databaseHelper = DatabaseHelperV2.instance;

  Future<int> insertInvoice(Invoice invoice) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('invoices', invoice.toMap());
    _databaseHelper.notifyDatabaseChanged();
    return id;
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await _databaseHelper.database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
    _databaseHelper.notifyDatabaseChanged();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT i.*, p.project_name, c.name as client_name
      FROM invoices i
      LEFT JOIN projects p ON i.project_id = p.id
      LEFT JOIN clients c ON i.client_id = c.id
      WHERE i.id = ?
    ''', [id]);
    
    if (maps.isNotEmpty) {
      return Invoice.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Invoice>> getInvoicesByProject(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT i.*, p.project_name, c.name as client_name
      FROM invoices i
      LEFT JOIN projects p ON i.project_id = p.id
      LEFT JOIN clients c ON i.client_id = c.id
      WHERE i.project_id = ? AND i.is_deleted = 0
      ORDER BY i.invoice_date DESC
    ''', [projectId]);
    
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<List<Invoice>> getInvoicesByClient(int clientId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT i.*, p.project_name, c.name as client_name
      FROM invoices i
      LEFT JOIN projects p ON i.project_id = p.id
      LEFT JOIN clients c ON i.client_id = c.id
      WHERE i.client_id = ? AND i.is_deleted = 0
      ORDER BY i.invoice_date DESC
    ''', [clientId]);
    
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<List<Invoice>> getAllInvoices({bool includeDeleted = false}) async {
    final db = await _databaseHelper.database;
    String query = '''
      SELECT i.*, p.project_name, c.name as client_name
      FROM invoices i
      LEFT JOIN projects p ON i.project_id = p.id
      LEFT JOIN clients c ON i.client_id = c.id
    ''';
    
    if (!includeDeleted) {
      query += ' WHERE i.is_deleted = 0';
    }
    
    query += ' ORDER BY i.invoice_date DESC';
    
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<void> softDeleteInvoice(int id, String reasonCode, String? notes) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      // 1. Soft delete the invoice itself
      await txn.update(
        'invoices',
        {
          'is_deleted': 1,
          'deleted_reason_code': reasonCode,
          'deleted_date': DateTime.now().toIso8601String(),
          'deleted_notes': notes,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 2. Reset associated time_entries to unbilled status
      await txn.update(
        'time_entries',
        {
          'is_billed': 0,
          'invoice_id': null,
        },
        where: 'invoice_id = ?',
        whereArgs: [id],
      );

      // 3. Reset associated materials/expenses to unbilled status
      await txn.update(
        'materials',
        {
          'is_billed': 0,
          'invoice_id': null,
        },
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
    });
    _databaseHelper.notifyDatabaseChanged();
  }

  Future<void> markInvoicePaid(int id, double amountPaid, String paymentMethod, DateTime paymentDate) async {
    final db = await _databaseHelper.database;
    await db.update(
      'invoices',
      {
        'is_paid': 1,
        'amount_paid': amountPaid,
        'payment_method': paymentMethod,
        'payment_date': paymentDate.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _databaseHelper.notifyDatabaseChanged();
  }

  Future<List<Project>> getActiveProjects() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'is_completed = 0',
      orderBy: 'project_name ASC',
    );
    return List.generate(maps.length, (i) => Project.fromMap(maps[i]));
  }

  Future<Client?> getClientById(int clientId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [clientId],
    );
    if (maps.isNotEmpty) {
      return Client.fromMap(maps.first);
    }
    return null;
  }

  Future<void> markSent(int invoiceId) async {
    final db = await _databaseHelper.database;
    await db.update(
      'invoices',
      {'is_sent': 1},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    _databaseHelper.notifyDatabaseChanged();
  }

  Future<void> markPaid(int invoiceId, double amountPaid, DateTime paymentDate, String? paymentMethod) async {
    final db = await _databaseHelper.database;
    await db.update(
      'invoices',
      {
        'is_paid': 1,
        'amount_paid': amountPaid,
        'payment_date': paymentDate.toIso8601String(),
        'payment_method': paymentMethod,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    _databaseHelper.notifyDatabaseChanged();
  }

  Future<void> softDelete(int invoiceId, String reasonCode, String? notes) async {
    final db = await _databaseHelper.database;
    await db.update(
      'invoices',
      {
        'is_deleted': 1,
        'deleted_reason_code': reasonCode,
        'deleted_date': DateTime.now().toIso8601String(),
        'deleted_notes': notes,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    _databaseHelper.notifyDatabaseChanged();
  }

  Future<Map<String, double>> getProjectBillingSummary(int projectId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(subtotal), 0) as total_billed,
        COALESCE(SUM(tax1_amount), 0) as total_gst
      FROM invoices
      WHERE project_id = ? AND is_deleted = 0
    ''', [projectId]);
    
    return {
      'total_billed': (result.first['total_billed'] as num).toDouble(),
      'total_gst': (result.first['total_gst'] as num).toDouble(),
    };
  }

  Future<Map<String, dynamic>> fetchUnbilledBillableRecords(int projectId) async {
    final db = await _databaseHelper.database;

    final timeEntries = await db.rawQuery("""
      SELECT te.*, cc.name as cost_code_name, e.name as employee_name
      FROM time_entries te
      LEFT JOIN cost_codes cc ON te.cost_code_id = cc.id
      LEFT JOIN employees e ON te.employee_id = e.id
      WHERE te.project_id = ?
        AND te.is_billed = 0
        AND te.is_deleted = 0
        AND cc.is_billable = 1
      ORDER BY cc.name, te.start_time ASC
    """, [projectId]);

    final materials = await db.rawQuery("""
      SELECT m.*, cc.name as cost_code_name
      FROM materials m
      LEFT JOIN cost_codes cc ON m.cost_code_id = cc.id
      WHERE m.project_id = ?
        AND m.is_billed = 0
        AND m.is_deleted = 0
        AND cc.is_billable = 1
      ORDER BY cc.name, m.purchase_date ASC
    """, [projectId]);

    return {
      'timeEntries': timeEntries,
      'materials': materials,
    };
  }

  Future<void> markRecordsAsBilled({
    required int invoiceId,
    required List<int> timeEntryIds,
    required List<int> materialIds,
  }) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();

    for (final id in timeEntryIds) {
      batch.update('time_entries',
        {'is_billed': 1, 'invoice_id': invoiceId},
        where: 'id = ?', whereArgs: [id]);
    }
    for (final id in materialIds) {
      batch.update('materials',
        {'is_billed': 1, 'invoice_id': invoiceId},
        where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
    _databaseHelper.notifyDatabaseChanged();
  }
}
