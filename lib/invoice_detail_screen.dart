// lib/invoice_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/create_invoice_screen.dart';
import 'package:printing/printing.dart';
import 'package:time_tracker_pro/invoice_pdf_service.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'extras_invoice_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ProjectRepository _projectRepository = ProjectRepository();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  static const _accentColor = Color(0xFFE8720C);
  static const _headerBgColor = Color(0xFF2D2D2D);

  final TextEditingController _internalNotesController = TextEditingController();
  final TextEditingController _workDescriptionController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

  Invoice? _invoice;
  Map<String, dynamic>? _companySettings;
  Client? _client;
  Project? _project;
  double _contractValue = 0;
  double _totalBilled = 0;
  double _totalGstCollected = 0;
  bool _isLoading = true;
  bool _isSavingFields = false;
  bool _isSavingInternalNotes = false;
  bool _hasUnsavedChanges = false;
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
    _workDescriptionController.addListener(_onFieldChanged);
    _termsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_invoice == null) return;
    final changed = _workDescriptionController.text != (_invoice!.workDescription ?? '') ||
        _termsController.text != _invoice!.terms;
    if (changed != _hasUnsavedChanges) setState(() => _hasUnsavedChanges = changed);
  }

  @override
  void dispose() {
    _internalNotesController.dispose();
    _workDescriptionController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    try {
      final invoice = await _invoiceRepository.getInvoiceById(widget.invoiceId);
      final settings = await AppDatabase.instance.getCompanySettings();
      Client? client;
      Project? project;
      double contractValue = 0;
      double totalBilled = 0;
      double totalGstCollected = 0;
      if (invoice != null) {
        client = await _invoiceRepository.getClientById(invoice.clientId);
        project = await _projectRepository.getProjectById(invoice.projectId);
        debugPrint('DEBUG INV detail: projectId=${invoice.projectId} pricingModel=${project?.pricingModel} fixedPrice=${project?.fixedPrice}');
        if (project != null &&
            project.pricingModel == 'fixed' &&
            (project.fixedPrice ?? 0) > 0) {
          try {
            final summary =
                await _invoiceRepository.getProjectBillingSummary(invoice.projectId);
            contractValue = project.fixedPrice ?? 0;
            totalBilled = (summary['total_billed'] as num? ?? 0).toDouble();
            totalGstCollected = (summary['total_gst'] as num? ?? 0).toDouble();
          } catch (_) {}
        }
      }
      setState(() {
        _invoice = invoice;
        _companySettings = settings.toMap();
        _client = client;
        _project = project;
        _contractValue = contractValue;
        _totalBilled = totalBilled;
        _totalGstCollected = totalGstCollected;
        _internalNotesController.text = invoice?.internalNotes ?? '';
        _workDescriptionController.text = invoice?.workDescription ?? '';
        _termsController.text = invoice?.terms ?? 'Payable on Receipt';
        _hasUnsavedChanges = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load invoice: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveInvoiceFields() async {
    if (_invoice == null) return;
    setState(() => _isSavingFields = true);
    try {
      final updated = _invoice!.copyWith(
        workDescription: _workDescriptionController.text.trim().isEmpty
            ? null
            : _workDescriptionController.text.trim(),
        terms: _termsController.text.trim().isEmpty
            ? 'Payable on Receipt'
            : _termsController.text.trim(),
      );
      await _invoiceRepository.updateInvoice(updated);
      setState(() {
        _invoice = updated;
        _hasUnsavedChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingFields = false);
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
    setState(() => _isLoading = true);
    try {
      final settingsMap = _companySettings ?? (await AppDatabase.instance.getCompanySettings()).toMap();
      final client = _client ?? await _invoiceRepository.getClientById(_invoice!.clientId);
      final project = _project ?? await _projectRepository.getProjectById(_invoice!.projectId);

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _paymentMethodLabel(String method) {
    const labels = {'cheque': 'Cheque', 'cash': 'Cash', 'etransfer': 'E-Transfer'};
    return labels[method] ?? method;
  }

  String _referenceFieldLabel(String? method) {
    if (method == 'cheque') return 'Cheque #';
    if (method == 'etransfer') return 'Confirmation #';
    return 'Reference';
  }

  Widget _buildStatusChip() {
    final invoice = _invoice!;
    String label;
    Color color;
    if (invoice.isDeleted) {
      label = 'Void'; color = Colors.red;
    } else if (invoice.isPaid) {
      label = 'Paid'; color = Colors.green;
    } else if ((invoice.amountPaid ?? 0) > 0) {
      label = 'Partial'; color = Colors.orange;
    } else if (invoice.isSent) {
      label = 'Sent'; color = Colors.blue;
    } else {
      label = 'Draft'; color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // ── Document layout helpers ───────────────────────────────────────────────

  Widget _docCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(color: _headerBgColor),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _totalsRow(String label, double amount, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_currencyFormat.format(amount.abs()), style: style),
        ],
      ),
    );
  }

  // ── Contract summary (fixed-price projects only) ─────────────────────────

  Widget _buildContractSummary() {
    final remaining = _contractValue - _totalBilled;
    final totalCollected = _totalBilled + _totalGstCollected;
    return _docCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CONTRACT SUMMARY'),
          const SizedBox(height: 10),
          _summaryRow('Contract Value', _currencyFormat.format(_contractValue)),
          _summaryRow('Previously Billed', _currencyFormat.format(_totalBilled)),
          _summaryRow('Total Collected', _currencyFormat.format(totalCollected)),
          const Divider(color: _accentColor, height: 16),
          _summaryRow(
            'Balance Remaining',
            _currencyFormat.format(remaining),
            bold: true,
            color: remaining > 0 ? Theme.of(context).primaryColor : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  // ── Main invoice document view ────────────────────────────────────────────

  Widget _buildInvoiceView() {
    final inv = _invoice!;
    final settings = _companySettings ?? {};
    final bool isLocked = inv.isPaid || inv.isDeleted;

    final companyName = (settings['company_name'] as String?) ?? '';
    final companyAddress = (settings['company_address'] as String?) ?? '';
    final companyCity = (settings['company_city'] as String?) ?? '';
    final companyProvince = (settings['company_province'] as String?) ?? '';
    final companyPostal = (settings['company_postal_code'] as String?) ?? '';
    final companyPhone = (settings['company_phone'] as String?) ?? '';
    final etransferEmail = (settings['payment_etransfer_email'] as String?) ?? '';
    final cityLine = [companyCity, '$companyProvince $companyPostal'.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── SECTION 1: Header ─────────────────────────────────────────────
          _docCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (companyName.isNotEmpty)
                            Text(companyName,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _accentColor)),
                          if (companyAddress.isNotEmpty)
                            Text(companyAddress, style: const TextStyle(fontSize: 12)),
                          if (cityLine.isNotEmpty)
                            Text(cityLine, style: const TextStyle(fontSize: 12)),
                          if (companyPhone.isNotEmpty)
                            Text('Tel: $companyPhone', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Invoice meta
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('INVOICE',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800)),
                            const SizedBox(width: 10),
                            _buildStatusChip(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_invoiceTypeLabels[inv.invoiceType] ?? inv.invoiceType}  ${inv.invoiceNumber}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(_dateFormat.format(inv.invoiceDate),
                            style: const TextStyle(fontSize: 12)),
                        if (inv.poNumber != null && inv.poNumber!.isNotEmpty)
                          Text('PO #: ${inv.poNumber!}',
                              style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: _accentColor, thickness: 1.5, height: 0),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── SECTION 2: Bill To / Project ──────────────────────────────────
          _docCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('BILL TO'),
                      const SizedBox(height: 8),
                      Text(inv.clientName ?? '—',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      if ((_project?.city ?? '').isNotEmpty)
                        Text(_project!.city!, style: const TextStyle(fontSize: 12)),
                      if ((_client?.phoneNumber ?? '').isNotEmpty)
                        Text(_client!.phoneNumber!, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('PROJECT'),
                      const SizedBox(height: 8),
                      Text(inv.projectName ?? '—',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      if ((inv.projectAddress ?? '').isNotEmpty)
                        Text(inv.projectAddress!, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── CONTRACT SUMMARY (fixed-price projects only) ──────────────────
          if (_project?.pricingModel == 'fixed' && _contractValue > 0) ...[
            _buildContractSummary(),
            const SizedBox(height: 8),
          ],

          // ── SECTION 3: Work Performed (editable) ──────────────────────────
          _docCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('WORK PERFORMED'),
                const SizedBox(height: 8),
                TextField(
                  controller: _workDescriptionController,
                  enabled: !isLocked,
                  maxLines: null,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: isLocked ? null : 'Describe the work performed on this invoice...',
                    border: isLocked ? InputBorder.none : const OutlineInputBorder(),
                    filled: !isLocked,
                    fillColor: Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── SECTION 4: Totals ─────────────────────────────────────────────
          _docCard(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 280,
                child: Column(
                  children: [
                    if (inv.invoiceType == 'extras') ...[
                      if (inv.labourSubtotal > 0)
                        _totalsRow('Labour', inv.labourSubtotal),
                      if (inv.materialsSubtotal > 0)
                        _totalsRow('Materials', inv.materialsSubtotal),
                      const Divider(color: _accentColor, height: 16),
                    ],
                    _totalsRow('Subtotal', inv.subtotal, bold: true),
                    if (inv.discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      _totalsRow(
                        inv.discountDescription ?? 'Discount',
                        -inv.discountAmount,
                        color: Colors.red,
                      ),
                    ],
                    if (inv.tax1Amount > 0) ...[
                      const SizedBox(height: 4),
                      _totalsRow(
                        '${inv.tax1Name ?? 'GST'} (${(inv.tax1Rate ?? 0).toStringAsFixed(1)}%)',
                        inv.tax1Amount,
                      ),
                    ],
                    if (inv.tax2Amount > 0) ...[
                      const SizedBox(height: 4),
                      _totalsRow(
                        '${inv.tax2Name ?? 'PST'} (${inv.tax2Rate?.toStringAsFixed(1)}%)',
                        inv.tax2Amount,
                      ),
                    ],
                    const Divider(color: _accentColor, height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(color: _accentColor),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL DUE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          Text(
                            _currencyFormat.format(inv.totalAmount),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── SECTION 5: Payment Terms (editable) ───────────────────────────
          _docCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('PAYMENT TERMS'),
                const SizedBox(height: 8),
                TextField(
                  controller: _termsController,
                  enabled: !isLocked,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    border: isLocked ? InputBorder.none : const OutlineInputBorder(),
                    filled: !isLocked,
                    fillColor: Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                if (etransferEmail.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'E-Transfer: $etransferEmail',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),

          // ── SAVE CHANGES ──────────────────────────────────────────────────
          if (_hasUnsavedChanges && !isLocked) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isSavingFields ? null : _saveInvoiceFields,
              icon: _isSavingFields
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],

          // ── PAYMENT INFO ──────────────────────────────────────────────────
          if (inv.isPaid || (inv.amountPaid ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _buildPaymentInfoCard(),
          ],

          // ── INTERNAL NOTES ────────────────────────────────────────────────
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: Colors.amber.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text('Internal Notes',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900)),
                      const Spacer(),
                      Text('Not printed on invoice',
                          style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.amber.shade700)),
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
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.amber))
                          : const Icon(Icons.save, size: 16),
                      label: const Text('Save Notes', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── VOID INFO ─────────────────────────────────────────────────────
          if (inv.isDeleted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Void Information',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  if (inv.deletedReasonCode != null)
                    _detailRow('Reason', inv.deletedReasonCode!),
                  if (inv.deletedDate != null)
                    _detailRow('Voided On', _dateFormat.format(inv.deletedDate!)),
                  if (inv.deletedNotes != null)
                    _detailRow('Notes', inv.deletedNotes!),
                ],
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ── Payment info card ────────────────────────────────────────────────────

  Widget _buildPaymentInfoCard() {
    final inv = _invoice!;
    final isPartial = !inv.isPaid && (inv.amountPaid ?? 0) > 0;
    final accentColor = inv.isPaid ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                inv.isPaid ? Icons.check_circle_outline : Icons.payments_outlined,
                color: accentColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                inv.isPaid ? 'Payment Information' : 'Partial Payment',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: accentColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (inv.paymentMethod != null)
            _detailRow('Method', _paymentMethodLabel(inv.paymentMethod!)),
          if (inv.paymentReference != null && inv.paymentReference!.isNotEmpty)
            _detailRow(_referenceFieldLabel(inv.paymentMethod), inv.paymentReference!),
          if (inv.paymentDate != null)
            _detailRow('Date', _dateFormat.format(inv.paymentDate!)),
          if (inv.amountPaid != null)
            _detailRow('Amount', _currencyFormat.format(inv.amountPaid!)),
          if (isPartial && inv.amountPaid != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 90,
                    child: Text('Balance Due',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      _currencyFormat.format(inv.totalAmount - inv.amountPaid!),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (inv.paymentNotes != null && inv.paymentNotes!.isNotEmpty)
            _detailRow('Notes', inv.paymentNotes!),
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
                        backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ),
              if (!isLocked) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _onSharePdf,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple, foregroundColor: Colors.white),
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
                        foregroundColor: Colors.white),
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
                        backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              if (!inv.isDeleted && !inv.isPaid) const SizedBox(width: 8),
              if (!inv.isDeleted && !inv.isPaid)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onVoid,
                    icon: const Icon(Icons.block),
                    label: const Text('Void'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        MaterialPageRoute(builder: (_) => ExtrasInvoiceScreen(existingInvoice: _invoice)),
      );
      if (result == true) await _loadInvoice();
    } else {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreateInvoiceScreen(existingInvoice: _invoice)),
      );
      if (result == true) await _loadInvoice();
    }
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
    if (_invoice == null) return;

    String selectedMethod = 'etransfer';
    final referenceController = TextEditingController();
    final amountController =
        TextEditingController(text: _invoice!.totalAmount.toStringAsFixed(2));
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final entered =
              double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
          final isPartial = entered < _invoice!.totalAmount - 0.005;
          final remaining = _invoice!.totalAmount - entered;

          return AlertDialog(
            title: const Text('Record Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Payment Method',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final pair in [
                        ['cheque', 'Cheque'],
                        ['cash', 'Cash'],
                        ['etransfer', 'E-Transfer'],
                      ])
                        ChoiceChip(
                          label: Text(pair[1]),
                          selected: selectedMethod == pair[0],
                          onSelected: (_) =>
                              setDialogState(() => selectedMethod = pair[0]),
                        ),
                    ],
                  ),
                  if (selectedMethod != 'cash') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText:
                            selectedMethod == 'cheque' ? 'Cheque #' : 'Confirmation #',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (isPartial && entered > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        'Partial payment — Remaining: ${_currencyFormat.format(remaining)}',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
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
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: Text(
                    isPartial && entered > 0 ? 'Record Partial Payment' : 'Mark Paid'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true) return;
    try {
      final entered =
          double.tryParse(amountController.text.replaceAll(',', '')) ??
              _invoice!.totalAmount;
      final fullyPaid = entered >= _invoice!.totalAmount - 0.005;
      final updated = _invoice!.copyWith(
        isPaid: fullyPaid,
        amountPaid: entered,
        paymentMethod: selectedMethod,
        paymentReference: referenceController.text.trim().isEmpty
            ? null
            : referenceController.text.trim(),
        paymentDate: selectedDate,
        paymentNotes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      await _invoiceRepository.updateInvoice(updated);
      await _loadInvoice();
      if (mounted) {
        final remaining = _invoice!.totalAmount - entered;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fullyPaid
                ? 'Invoice marked as paid.'
                : 'Partial payment recorded. Remaining: ${_currencyFormat.format(remaining)}'),
            backgroundColor: Colors.green,
          ),
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
        title: Text(_invoice?.invoiceNumber ?? 'Invoice'),
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
