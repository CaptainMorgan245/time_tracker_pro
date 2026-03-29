// lib/invoice_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/invoice_service.dart';
import 'package:time_tracker_pro/create_invoice_screen.dart';
import 'package:printing/printing.dart';
import 'package:time_tracker_pro/invoice_pdf_service.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'extras_invoice_screen.dart';

// start class: InvoiceDetailScreen
class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}
// end class: InvoiceDetailScreen

// start class: _InvoiceDetailScreenState
class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ProjectRepository _projectRepository = ProjectRepository();
  final InvoiceService _invoiceService = InvoiceService.instance;
  final NumberFormat _currencyFormat =
  NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  final TextEditingController _internalNotesController = TextEditingController();
  Invoice? _invoice;
  bool _isLoading = true;
  bool _isSavingInternalNotes = false;
  String? _errorMessage;

  static const Map<String, String> _invoiceTypeLabels = {
    'progress': 'Progress Draw',
    'chargeable': 'Chargeable Extra',
    'addendum': 'Addendum',
    'deposit': 'Deposit',
    'extras': 'Time & Materials Invoice',
  };

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  @override
  void dispose() {
    _internalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    try {
      final invoice = await _invoiceRepository.getInvoiceById(widget.invoiceId);
      setState(() {
        _invoice = invoice;
        _internalNotesController.text = invoice?.internalNotes ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load invoice: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveInternalNotes() async {
    if (_invoice == null) return;
    setState(() => _isSavingInternalNotes = true);
    try {
      final updated = _invoice!.copyWith(
        internalNotes: _internalNotesController.text.trim(),
      );
      await _invoiceRepository.updateInvoice(updated);
      _invoice = updated;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Internal notes saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notes: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingInternalNotes = false);
    }
  }

  Future<void> _onSharePdf() async {
    if (_invoice == null) return;

    try {
      // Show loading indicator
      setState(() => _isLoading = true);

      // 1. Load company settings
      final settings = await AppDatabase.instance.getCompanySettings();
      final settingsMap = settings.toMap();

      // 2. Load client details
      final client = await _invoiceRepository.getClientById(_invoice!.clientId);

      // 3. Load project details
      final project = await _projectRepository.getProjectById(_invoice!.projectId);

      // 4. Generate PDF
      final pdfBytes = await InvoicePdfService.generateInvoicePdf(
        invoice: _invoice!,
        companySettings: settingsMap,
        clientName: client?.name ?? '',
        clientCity: project?.city ?? '',
        clientPhone: client?.phoneNumber ?? '',
        projectName: project?.projectName ?? '',
        projectStreetAddress: project?.streetAddress ?? '',
        projectCity: project?.city ?? '',
        projectRegion: project?.region ?? '',
        projectPostalCode: project?.postalCode ?? '',
      );

      setState(() => _isLoading = false);

      // 5. Show print/share preview using printing package
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Invoice_${_invoice!.invoiceNumber}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  // ── Status chip ───────────────────────────────────────────────────────────

  Widget _buildStatusChip() {
    final invoice = _invoice!;
    String label;
    Color color;

    if (invoice.isDeleted) {
      label = 'Void';
      color = Colors.red;
    } else if (invoice.isPaid) {
      label = 'Paid';
      color = Colors.green;
    } else if (invoice.isSent) {
      label = 'Sent';
      color = Colors.blue;
    } else {
      label = 'Draft';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ── Invoice view ──────────────────────────────────────────────────────────

  Widget _buildInvoiceView() {
    final inv = _invoice!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _invoiceTypeLabels[inv.invoiceType] ?? inv.invoiceType,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const Divider(height: 24, thickness: 1.5),
                  _buildDetailRow('Date', _dateFormat.format(inv.invoiceDate)),
                  const SizedBox(height: 8),
                  _buildDetailRow('Project', inv.projectName ?? '—'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Client', inv.clientName ?? '—'),
                  if (inv.projectAddress != null && inv.projectAddress!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Address', inv.projectAddress!),
                  ],
                  if (inv.poNumber != null && inv.poNumber!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('PO Number', inv.poNumber!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Amounts card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Amount Summary',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (inv.labourSubtotal > 0)
                    _buildAmountRow('Labour', inv.labourSubtotal),
                  if (inv.materialsSubtotal > 0)
                    _buildAmountRow('Materials', inv.materialsSubtotal),
                  if (inv.materialsPickupCost > 0)
                    _buildAmountRow('Pickup Costs', inv.materialsPickupCost),
                  if (inv.otherCosts > 0)
                    _buildAmountRow(
                      inv.otherCostsDescription ?? 'Other',
                      inv.otherCosts,
                    ),
                  if (inv.discountAmount > 0)
                    _buildAmountRow('Discount', -inv.discountAmount, color: Colors.green),
                  const Divider(height: 20, thickness: 1),
                  _buildAmountRow('Subtotal', inv.subtotal),
                  if (inv.tax1Amount > 0)
                    _buildAmountRow(
                      '${inv.tax1Name ?? 'GST'} (${inv.tax1Rate?.toStringAsFixed(1) ?? '5.0'}%)',
                      inv.tax1Amount,
                    ),
                  const Divider(height: 20, thickness: 1.5),
                  _buildAmountRow('Total Due', inv.totalAmount,
                      bold: true,
                      color: inv.isPaid ? Colors.green : Theme.of(context).primaryColor,
                      fontSize: 18),
                  if (inv.isPaid && inv.amountPaid != null) ...[
                    const SizedBox(height: 8),
                    _buildAmountRow('Amount Paid', inv.amountPaid!,
                        color: Colors.green),
                    if (inv.paymentDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Paid ${_dateFormat.format(inv.paymentDate!)}'
                              '${inv.paymentMethod != null ? ' via ${inv.paymentMethod}' : ''}',
                          style: TextStyle(
                              color: Colors.green.shade700, fontSize: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Internal notes (VISUALLY DISTINCT)
          const SizedBox(height: 12),
          Card(
            elevation: 4,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text('Internal Notes',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                      const Spacer(),
                      const Text('Not printed on invoice', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.amber)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _internalNotesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add private notes here...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 14),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isSavingInternalNotes ? null : _saveInternalNotes,
                      icon: _isSavingInternalNotes 
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                        : const Icon(Icons.save, size: 16),
                      label: const Text('Save Notes', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Terms / notes card
          if ((inv.terms != null && inv.terms!.isNotEmpty) ||
              (inv.notes != null && inv.notes!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inv.terms != null && inv.terms!.isNotEmpty) ...[
                      Text('Terms',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(inv.terms!,
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                    if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Notes (Printed on Invoice)',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(inv.notes!,
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Void info
          if (inv.isDeleted) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Void Information',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                    if (inv.deletedReasonCode != null)
                      _buildDetailRow('Reason', inv.deletedReasonCode!),
                    if (inv.deletedDate != null)
                      _buildDetailRow('Voided On', _dateFormat.format(inv.deletedDate!)),
                    if (inv.deletedNotes != null)
                      _buildDetailRow('Notes', inv.deletedNotes!),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amount,
      {bool bold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: fontSize)),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final inv = _invoice!;
    final bool isLocked = inv.isPaid || inv.isDeleted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 55),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (!isLocked)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (!isLocked) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _onSharePdf,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!inv.isSent && !isLocked)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onMarkSent,
                    icon: const Icon(Icons.send),
                    label: const Text('Mark Sent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (!inv.isSent && !isLocked) const SizedBox(width: 8),
              if (!inv.isPaid && !inv.isDeleted)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onMarkPaid,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (!inv.isDeleted && inv.isPaid == false)
                const SizedBox(width: 8),
              if (!inv.isDeleted && !inv.isPaid)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onVoid,
                    icon: const Icon(Icons.block),
                    label: const Text('Void'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onEdit() async {
    if (_invoice?.invoiceType == 'extras') {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExtrasInvoiceScreen(existingInvoice: _invoice),
        ),
      );
      if (result == true) await _loadInvoice();
    } else {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateInvoiceScreen(existingInvoice: _invoice),
        ),
      );
      if (result == true) _loadInvoice();
    }
  }

  void _onShare() {
    // TODO: Generate PDF and share
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF share — coming soon')),
    );
  }

  Future<void> _onMarkSent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Sent?'),
        content: const Text(
            'This will mark the invoice as sent. You can still edit it until it is paid.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark Sent')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _invoiceRepository.markSent(_invoice!.id!);
      await _loadInvoice();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onMarkPaid() async {
    final paymentMethodController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark as Paid?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('The invoice will be locked and cannot be edited.'),
                const SizedBox(height: 20),
                
                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFormat.format(selectedDate)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextField(
                  controller: paymentMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method (optional)',
                    hintText: 'e.g. E-transfer, Cheque, Cash',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Paid'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    try {
      await _invoiceRepository.markPaid(
        _invoice!.id!,
        _invoice!.totalAmount,
        paymentMethodController.text.trim().isEmpty
            ? ''
            : paymentMethodController.text.trim(),
        selectedDate,
      );
      await _loadInvoice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invoice marked as paid.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onVoid() async {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Invoice?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Voiding an invoice cannot be undone. Please provide a reason.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason Code *',
                hintText: 'e.g. Duplicate, Error, Cancelled',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Void Invoice'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _invoiceRepository.softDelete(
        _invoice!.id!,
        reasonController.text.trim(),
        notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );
      await _loadInvoice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice voided.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice?.invoiceNumber ?? 'Invoice Detail'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.red)))
          : Column(
        children: [
          Expanded(child: _buildInvoiceView()),
          _buildActionButtons(),
        ],
      ),
    );
  }
}
// end class: _InvoiceDetailScreenState
