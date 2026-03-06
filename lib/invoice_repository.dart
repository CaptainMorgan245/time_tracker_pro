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
}
