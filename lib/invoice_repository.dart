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
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Invoice.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Invoice>> getInvoicesByProject(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'project_id = ? AND is_deleted = 0',
      whereArgs: [projectId],
      orderBy: 'invoice_date DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<List<Invoice>> getInvoicesByClient(int clientId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'client_id = ? AND is_deleted = 0',
      whereArgs: [clientId],
      orderBy: 'invoice_date DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  Future<List<Invoice>> getAllInvoices({bool includeDeleted = false}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'invoice_date DESC',
    );
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
}
