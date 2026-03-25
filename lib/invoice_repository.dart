// lib/invoice_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class InvoiceRepository {
  final _db = AppDatabase.instance;

  Future<int> insertInvoice(Invoice invoice) async {
    final map = invoice.toMap()
      ..remove('project_name')
      ..remove('client_name');
    final cols = map.keys.join(', ');
    final placeholders = map.keys.map((_) => '?').join(', ');
    final values = map.values.map((v) => Variable(v)).toList();
    final id = await _db.customInsert(
      'INSERT OR REPLACE INTO invoices ($cols) VALUES ($placeholders)',
      variables: values,
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final rows = await _db.customSelect(
      '''SELECT i.*, p.project_name, c.name as client_name
         FROM invoices i
         JOIN projects p ON i.project_id = p.id
         JOIN clients c ON i.client_id = c.id
         WHERE i.id = ?''',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first.data);
  }

  Future<List<Invoice>> getAllInvoices({bool includeDeleted = false}) async {
    final whereClause = includeDeleted ? '' : 'WHERE i.is_deleted = 0';
    final rows = await _db.customSelect(
      '''SELECT i.*, p.project_name, c.name as client_name
         FROM invoices i
         JOIN projects p ON i.project_id = p.id
         JOIN clients c ON i.client_id = c.id
         $whereClause
         ORDER BY i.invoice_date DESC''',
    ).get();
    return rows.map((r) => Invoice.fromMap(r.data)).toList();
  }

  Future<List<Invoice>> getInvoicesByProject(int projectId) async {
    final rows = await _db.customSelect(
      '''SELECT i.*, p.project_name, c.name as client_name
         FROM invoices i
         JOIN projects p ON i.project_id = p.id
         JOIN clients c ON i.client_id = c.id
         WHERE i.project_id = ?
         ORDER BY i.invoice_date DESC''',
      variables: [Variable.withInt(projectId)],
    ).get();
    return rows.map((r) => Invoice.fromMap(r.data)).toList();
  }

  Future<List<Invoice>> getInvoicesByClient(int clientId) async {
    final rows = await _db.customSelect(
      '''SELECT i.*, p.project_name, c.name as client_name
         FROM invoices i
         JOIN projects p ON i.project_id = p.id
         JOIN clients c ON i.client_id = c.id
         WHERE i.client_id = ?
         ORDER BY i.invoice_date DESC''',
      variables: [Variable.withInt(clientId)],
    ).get();
    return rows.map((r) => Invoice.fromMap(r.data)).toList();
  }

  Future<int> updateInvoice(Invoice invoice) async {
    final map = invoice.toMap()
      ..remove('project_name')
      ..remove('client_name');
    final setClauses =
        map.keys.where((k) => k != 'id').map((k) => '$k = ?').join(', ');
    final values = map.entries
        .where((e) => e.key != 'id')
        .map((e) => Variable(e.value))
        .toList()
      ..add(Variable.withInt(invoice.id!));
    final result = await _db.customUpdate(
      'UPDATE invoices SET $setClauses WHERE id = ?',
      variables: values,
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  // softDeleteInvoice — named parameters to match invoice_service.dart calls
  Future<int> softDeleteInvoice(int id, String reasonCode, String? notes) async {
    final result = await _db.customUpdate(
      'UPDATE invoices SET is_deleted = 1, deleted_date = ?, deleted_reason_code = ?, deleted_notes = ? WHERE id = ?',
      variables: [
        Variable.withString(DateTime.now().toIso8601String()),
        Variable.withString(reasonCode),
        Variable(notes),
        Variable.withInt(id),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  // Alias used by invoice_detail_screen.dart
  Future<void> softDelete(int id, String reasonCode, String? notes) async {
    await softDeleteInvoice(id, reasonCode, notes);
  }

  // markInvoicePaid — positional parameters to match invoice_service.dart calls
  Future<int> markInvoicePaid(
      int id, double amountPaid, String paymentMethod, DateTime paymentDate) async {
    final result = await _db.customUpdate(
      'UPDATE invoices SET is_paid = 1, amount_paid = ?, payment_method = ?, payment_date = ? WHERE id = ?',
      variables: [
        Variable.withReal(amountPaid),
        Variable.withString(paymentMethod),
        Variable.withString(paymentDate.toIso8601String()),
        Variable.withInt(id),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  // Alias used by invoice_detail_screen.dart
  Future<void> markPaid(int id, double amountPaid, String paymentMethod, DateTime paymentDate) async {
    await markInvoicePaid(id, amountPaid, paymentMethod, paymentDate);
  }

  Future<int> markInvoiceSent(int id) async {
    final result = await _db.customUpdate(
      'UPDATE invoices SET is_sent = 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  // Alias used by invoice_detail_screen.dart
  Future<void> markSent(int id) async {
    await markInvoiceSent(id);
  }

  Future<String> getNextInvoiceNumber() async {
    final year = DateTime.now().year;
    final prefix = 'INV-$year-';
    final rows = await _db.customSelect(
      "SELECT invoice_number FROM invoices WHERE invoice_number LIKE '$prefix%' ORDER BY invoice_number DESC LIMIT 1",
    ).get();
    if (rows.isEmpty) return '${prefix}001';
    final last = rows.first.data['invoice_number'] as String;
    final parts = last.split('-');
    if (parts.length == 3) {
      final next = (int.tryParse(parts[2]) ?? 0) + 1;
      return '$prefix${next.toString().padLeft(3, '0')}';
    }
    return '${prefix}001';
  }

  Future<List<Project>> getProjectsForClient(int clientId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM projects WHERE client_id = ? ORDER BY project_name',
      variables: [Variable.withInt(clientId)],
    ).get();
    return rows.map((r) => Project.fromMap(r.data)).toList();
  }

  // Alias used by create_invoice_screen.dart
  Future<List<Project>> getActiveProjects() async {
    final rows = await _db.customSelect(
      'SELECT * FROM projects WHERE is_completed = 0 ORDER BY project_name',
    ).get();
    return rows.map((r) => Project.fromMap(r.data)).toList();
  }

  Future<Client?> getClientById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM clients WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first.data);
  }

  Future<void> markTimeEntriesBilled(List<int> ids, int invoiceId) async {
    if (ids.isEmpty) return;
    final placeholders = ids.map((_) => '?').join(',');
    await _db.customUpdate(
      'UPDATE time_entries SET is_billed = 1, invoice_id = ? WHERE id IN ($placeholders)',
      variables: [
        Variable.withInt(invoiceId),
        ...ids.map((id) => Variable.withInt(id))
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
  }

  Future<void> markMaterialsBilled(List<int> ids, int invoiceId) async {
    if (ids.isEmpty) return;
    final placeholders = ids.map((_) => '?').join(',');
    await _db.customUpdate(
      'UPDATE materials SET is_billed = 1, invoice_id = ? WHERE id IN ($placeholders)',
      variables: [
        Variable.withInt(invoiceId),
        ...ids.map((id) => Variable.withInt(id))
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
  }

  Future<void> unmarkTimeEntriesBilled(int invoiceId) async {
    await _db.customUpdate(
      'UPDATE time_entries SET is_billed = 0, invoice_id = NULL WHERE invoice_id = ?',
      variables: [Variable.withInt(invoiceId)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
  }

  Future<void> unmarkMaterialsBilled(int invoiceId) async {
    await _db.customUpdate(
      'UPDATE materials SET is_billed = 0, invoice_id = NULL WHERE invoice_id = ?',
      variables: [Variable.withInt(invoiceId)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
  }

  // Used by extras_invoice_screen.dart
  Future<Map<String, List<dynamic>>> fetchUnbilledBillableRecords(
      int projectId) async {
    final teRows = await _db.customSelect(
      '''SELECT t.*, cc.name as cost_code_name
         FROM time_entries t
         LEFT JOIN cost_codes cc ON t.cost_code_id = cc.id
         WHERE t.project_id = ? AND t.is_billed = 0 AND t.is_deleted = 0
           AND t.cost_code_id IN (SELECT id FROM cost_codes WHERE is_billable = 1)
         ORDER BY t.start_time ASC''',
      variables: [Variable.withInt(projectId)],
    ).get();

    final matRows = await _db.customSelect(
      '''SELECT m.*, cc.name as cost_code_name
         FROM materials m
         LEFT JOIN cost_codes cc ON m.cost_code_id = cc.id
         WHERE m.project_id = ? AND m.is_billed = 0 AND m.is_deleted = 0
           AND m.cost_code_id IN (SELECT id FROM cost_codes WHERE is_billable = 1)
         ORDER BY m.purchase_date ASC''',
      variables: [Variable.withInt(projectId)],
    ).get();

    return {
      'timeEntries': teRows.map((r) => TimeEntry.fromMap(r.data)).toList(),
      'materials': matRows.map((r) => JobMaterials.fromMap(r.data)).toList(),
    };
  }

  // Used by extras_invoice_screen.dart
  Future<void> markRecordsAsBilled({
    required List<int> timeEntryIds,
    required List<int> materialIds,
    required int invoiceId,
  }) async {
    await markTimeEntriesBilled(timeEntryIds, invoiceId);
    await markMaterialsBilled(materialIds, invoiceId);
  }

  // Used by create_invoice_screen.dart
  Future<Map<String, dynamic>> getProjectBillingSummary(int projectId) async {
    final teRows = await _db.customSelect(
      'SELECT SUM(final_billed_duration_seconds * hourly_rate / 3600.0) as labour_total '
      'FROM time_entries WHERE project_id = ? AND is_deleted = 0',
      variables: [Variable.withInt(projectId)],
    ).get();
    final matRows = await _db.customSelect(
      'SELECT SUM(cost) as materials_total FROM materials WHERE project_id = ? AND is_deleted = 0',
      variables: [Variable.withInt(projectId)],
    ).get();
    return {
      'labour_total':
          (teRows.first.data['labour_total'] as num? ?? 0).toDouble(),
      'materials_total':
          (matRows.first.data['materials_total'] as num? ?? 0).toDouble(),
    };
  }
}
