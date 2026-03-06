import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/invoice.dart';
import 'package:time_tracker_pro/invoice_repository.dart';

class InvoiceService {
  InvoiceService._privateConstructor();
  static final InvoiceService instance = InvoiceService._privateConstructor();

  final _invoiceRepository = InvoiceRepository();
  final _databaseHelper = DatabaseHelperV2.instance;

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

  Future<void> markInvoicePaid(int id, double amountPaid, String paymentMethod, DateTime paymentDate) async {
    await _invoiceRepository.markInvoicePaid(id, amountPaid, paymentMethod, paymentDate);
  }

  Future<List<TimeEntry>> getUnbilledTimeEntries(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'project_id = ? AND is_billed = 0 AND is_deleted = 0',
      whereArgs: [projectId],
      orderBy: 'start_time ASC',
    );
    return List.generate(maps.length, (i) => TimeEntry.fromMap(maps[i]));
  }

  Future<List<JobMaterials>> getUnbilledMaterials(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'materials',
      where: 'project_id = ? AND is_billed = 0 AND is_deleted = 0',
      whereArgs: [projectId],
      orderBy: 'purchase_date ASC',
    );
    return List.generate(maps.length, (i) => JobMaterials.fromMap(maps[i]));
  }

  Future<String> generateInvoiceNumber() async {
    final db = await _databaseHelper.database;
    final currentYear = DateTime.now().year;
    
    // Find the max invoice number that starts with INV-YEAR-
    final prefix = 'INV-$currentYear-';
    final result = await db.rawQuery(
      "SELECT invoice_number FROM invoices WHERE invoice_number LIKE '$prefix%' ORDER BY invoice_number DESC LIMIT 1"
    );

    int nextSequence = 1;

    if (result.isNotEmpty) {
      final lastInvoiceNumber = result.first['invoice_number'] as String;
      // Extract the last 3 digits
      final parts = lastInvoiceNumber.split('-');
      if (parts.length == 3) {
        final lastSequence = int.tryParse(parts[2]);
        if (lastSequence != null) {
          nextSequence = lastSequence + 1;
        }
      }
    }

    // Return in format INV-YYYY-NNN
    return '$prefix${nextSequence.toString().padLeft(3, '0')}';
  }
}
