// lib/invoice_service.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';

class InvoiceService {
  InvoiceService._privateConstructor();
  static final InvoiceService instance = InvoiceService._privateConstructor();

  final _invoiceRepository = InvoiceRepository();
  final _db = AppDatabase.instance;

  Future<Invoice> createInvoice(Invoice invoice) async {
    final id = await _invoiceRepository.insertInvoice(invoice);
    return invoice.copyWith(id: id);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await _invoiceRepository.updateInvoice(invoice);
  }

  Future<Invoice?> getInvoiceById(int id) async {
    return await _invoiceRepository.getInvoiceById(id);
  }

  Future<List<Invoice>> getInvoicesByProject(int projectId) async {
    return await _invoiceRepository.getInvoicesByProject(projectId);
  }

  Future<List<Invoice>> getInvoicesByClient(int clientId) async {
    return await _invoiceRepository.getInvoicesByClient(clientId);
  }

  Future<List<Invoice>> getAllInvoices({bool includeDeleted = false}) async {
    return await _invoiceRepository.getAllInvoices(includeDeleted: includeDeleted);
  }

  Future<void> softDeleteInvoice(int id, String reasonCode, String? notes) async {
    await _invoiceRepository.softDeleteInvoice(id, reasonCode, notes);
  }

  Future<void> markInvoicePaid(
      int id, double amountPaid, String paymentMethod, DateTime paymentDate) async {
    await _invoiceRepository.markInvoicePaid(id, amountPaid, paymentMethod, paymentDate);
  }

  Future<List<TimeEntry>> getUnbilledTimeEntries(int projectId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM time_entries WHERE project_id = ? AND is_billed = 0 AND is_deleted = 0 ORDER BY start_time ASC',
      variables: [Variable.withInt(projectId)],
    ).get();
    return rows.map((r) => TimeEntry.fromMap(r.data)).toList();
  }

  Future<List<JobMaterials>> getUnbilledMaterials(int projectId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM materials WHERE project_id = ? AND is_billed = 0 AND is_deleted = 0 ORDER BY purchase_date ASC',
      variables: [Variable.withInt(projectId)],
    ).get();
    return rows.map((r) => JobMaterials.fromMap(r.data)).toList();
  }

  Future<String> generateInvoiceNumber() async {
    return await _invoiceRepository.getNextInvoiceNumber();
  }
}
