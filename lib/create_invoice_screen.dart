// lib/create_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/invoice_service.dart';

// start class: CreateInvoiceScreen
class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? existingInvoice; // null = create, non-null = edit

  const CreateInvoiceScreen({super.key, this.existingInvoice});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}
// end class: CreateInvoiceScreen

// start class: _CreateInvoiceScreenState
class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final InvoiceService _invoiceService = InvoiceService.instance;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');

  // Form controllers
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form state
  List<Project> _projects = [];
  Project? _selectedProject;
  Client? _selectedProjectClient;
  String _invoiceType = 'progress';
  DateTime _invoiceDate = DateTime.now();
  bool _isFinalInvoice = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Contract summary for fixed price projects
  double _totalPreviouslyBilled = 0;
  double _totalGstCollected = 0;
  bool _loadingBillingSummary = false;

  bool get _isEditMode => widget.existingInvoice != null;
  bool get _isFixedPrice =>
      _selectedProject?.pricingModel == 'fixed' &&
      (_selectedProject?.fixedPrice ?? 0) > 0;

  static const Map<String, String> _invoiceTypeLabels = {
    'progress': 'Progress Draw',
    'chargeable': 'Chargeable Extra',
    'addendum': 'Addendum',
    'deposit': 'Deposit',
  };

  // ── Calculated fields ─────────────────────────────────────────────────────

  double get _enteredAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

  double get _gstAmount {
    if (_isFixedPrice && _isFinalInvoice) {
      // Reconciliation: GST on full contract minus previously collected
      final contractGst = (_selectedProject!.fixedPrice ?? 0) * 0.05;
      return (contractGst - _totalGstCollected).clamp(0, double.infinity);
    }
    return _enteredAmount * 0.05;
  }

  double get _finalAmount {
    if (_isFixedPrice && _isFinalInvoice) {
      // Remaining balance = contract total - previously billed
      return ((_selectedProject!.fixedPrice ?? 0) - _totalPreviouslyBilled)
          .clamp(0, double.infinity);
    }
    return _enteredAmount;
  }

  double get _total => _finalAmount + _gstAmount;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _loadProjects();

    // Pre-populate if editing
    if (_isEditMode) {
      final inv = widget.existingInvoice!;
      _invoiceDate = inv.invoiceDate;
      _invoiceType = inv.invoiceType;
      _notesController.text = inv.notes ?? '';
      _poNumberController.text = inv.poNumber ?? '';
      _descriptionController.text = inv.otherCostsDescription ?? '';
      // Amount is the subtotal
      _amountController.text = inv.subtotal.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _poNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await _invoiceRepository.getActiveProjects();
      setState(() {
        _projects = projects;
        _isLoading = false;
      });

      // If editing, find and select the existing project
      if (_isEditMode) {
        final match = projects.where(
            (p) => p.id == widget.existingInvoice!.projectId).toList();
        if (match.isNotEmpty) {
          await _onProjectSelected(match.first, silent: true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load projects: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onProjectSelected(Project? project,
      {bool silent = false}) async {
    if (project == null) return;
    setState(() {
      _selectedProject = project;
      _loadingBillingSummary = true;
      if (!silent) {
        // Auto-select invoice type based on pricing model
        _invoiceType =
            project.pricingModel == 'fixed' ? 'progress' : 'chargeable';
        _isFinalInvoice = false;
      }
    });

    // Load client
    try {
      final client =
          await _invoiceRepository.getClientById(project.clientId);
      setState(() => _selectedProjectClient = client);
    } catch (_) {
      setState(() => _selectedProjectClient = null);
    }

    // Load billing summary for fixed price projects
    if (project.pricingModel == 'fixed' &&
        (project.fixedPrice ?? 0) > 0) {
      try {
        final summary =
            await _invoiceRepository.getProjectBillingSummary(project.id!);
        // Exclude current invoice if editing
        double billed = summary['total_billed'] ?? 0;
        double gst = summary['total_gst'] ?? 0;
        if (_isEditMode) {
          billed -= widget.existingInvoice!.subtotal;
          gst -= widget.existingInvoice!.tax1Amount ?? 0;
        }
        setState(() {
          _totalPreviouslyBilled = billed;
          _totalGstCollected = gst;
          _loadingBillingSummary = false;
        });
      } catch (_) {
        setState(() => _loadingBillingSummary = false);
      }
    } else {
      setState(() => _loadingBillingSummary = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProject == null) {
      setState(() => _errorMessage = 'Please select a project.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final subtotal = _finalAmount;
      final gst = _gstAmount;
      final total = subtotal + gst;

      String invoiceNumber = _isEditMode
          ? widget.existingInvoice!.invoiceNumber
          : await _invoiceService.generateInvoiceNumber();

      final invoice = Invoice(
        id: _isEditMode ? widget.existingInvoice!.id : 0,
        invoiceNumber: invoiceNumber,
        invoiceDate: _invoiceDate,
        clientId: _selectedProject!.clientId,
        projectId: _selectedProject!.id!,
        projectAddress: _selectedProject!.location,
        labourSubtotal: _invoiceType == 'chargeable' ? subtotal : 0,
        materialsSubtotal: 0,
        materialsPickupCost: 0,
        otherCosts:
            _invoiceType == 'progress' || _invoiceType == 'addendum'
                ? subtotal
                : 0,
        otherCostsDescription: _descriptionController.text.trim().isEmpty
            ? _invoiceTypeLabels[_invoiceType]
            : _descriptionController.text.trim(),
        discountAmount: 0,
        discountPercent: 0,
        tax1Name: 'GST',
        tax1Rate: 5.0,
        tax1Amount: gst,
        tax1RegistrationNumber: null,
        tax2Name: null,
        tax2Rate: null,
        tax2Amount: 0,
        tax2RegistrationNumber: null,
        subtotal: subtotal,
        totalAmount: total,
        terms: 'Payable on Receipt',
        poNumber: _poNumberController.text.trim().isEmpty
            ? null
            : _poNumberController.text.trim(),
        isPaid: _isEditMode ? widget.existingInvoice!.isPaid : false,
        amountPaid: _isEditMode ? widget.existingInvoice!.amountPaid : null,
        paymentDate:
            _isEditMode ? widget.existingInvoice!.paymentDate : null,
        paymentMethod:
            _isEditMode ? widget.existingInvoice!.paymentMethod : null,
        isDeleted: false,
        deletedReasonCode: null,
        deletedDate: null,
        deletedNotes: null,
        supersededByInvoiceId: null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isSent: _isEditMode ? widget.existingInvoice!.isSent : false,
        invoiceType: _invoiceType,
      );

      if (_isEditMode) {
        await _invoiceRepository.updateInvoice(invoice);
      } else {
        await _invoiceService.createInvoice(invoice);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Invoice updated.'
                : 'Invoice $invoiceNumber created as draft.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save invoice: $e';
        _isSaving = false;
      });
    }
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }

  Widget _buildProjectDropdown() {
    return DropdownButtonFormField<Project>(
      value: _selectedProject,
      decoration: const InputDecoration(
        labelText: 'Project *',
        border: OutlineInputBorder(),
      ),
      hint: const Text('Select a project'),
      items: _projects.map((p) {
        return DropdownMenuItem<Project>(
          value: p,
          child: Text(p.projectName),
        );
      }).toList(),
      onChanged: (p) => _onProjectSelected(p),
      validator: (value) =>
          value == null ? 'Please select a project' : null,
    );
  }

  Widget _buildClientField() {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Client',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      controller: TextEditingController(
          text: _selectedProjectClient?.name ?? '—'),
    );
  }

  // ── Contract summary panel ────────────────────────────────────────────────

  Widget _buildContractSummary() {
    if (!_isFixedPrice) return const SizedBox.shrink();
    if (_loadingBillingSummary) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final contractValue = _selectedProject!.fixedPrice ?? 0;
    final remaining = contractValue - _totalPreviouslyBilled;

    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contract Summary',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    )),
            const SizedBox(height: 10),
            _summaryRow('Contract Value',
                _currencyFormat.format(contractValue)),
            _summaryRow('Previously Billed',
                _currencyFormat.format(_totalPreviouslyBilled)),
            _summaryRow('GST Collected',
                _currencyFormat.format(_totalGstCollected)),
            const Divider(height: 16),
            _summaryRow(
              'Remaining Balance',
              _currencyFormat.format(remaining),
              bold: true,
              color: remaining > 0
                  ? Theme.of(context).primaryColor
                  : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _buildFinalInvoiceToggle() {
    if (!_isFixedPrice) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Checkbox(
            value: _isFinalInvoice,
            onChanged: (val) =>
                setState(() => _isFinalInvoice = val ?? false),
          ),
          const Expanded(
            child: Text(
              'This is the final invoice — calculate reconciled GST',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _invoiceType,
      decoration: const InputDecoration(
        labelText: 'Invoice Type *',
        border: OutlineInputBorder(),
      ),
      items: _invoiceTypeLabels.entries.map((e) {
        return DropdownMenuItem<String>(
          value: e.key,
          child: Text(e.value),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _invoiceType = value);
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Invoice Date *',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
            DateFormat('MMMM d, yyyy').format(_invoiceDate)),
      ),
    );
  }

  Widget _buildAmountField() {
    if (_isFixedPrice && _isFinalInvoice) {
      // Final invoice — amount is calculated, show read only
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Amount (calculated)',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        child: Text(_currencyFormat.format(_finalAmount)),
      );
    }
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: 'Amount (before GST) *',
        border: OutlineInputBorder(),
        prefixText: '\$ ',
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (_isFixedPrice && _isFinalInvoice) return null;
        if (value == null || value.isEmpty)
          return 'Please enter an amount';
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0)
          return 'Please enter a valid amount';
        return null;
      },
    );
  }

  Widget _buildGstSummary() {
    final showAmount =
        (_isFixedPrice && _isFinalInvoice) || _enteredAmount > 0;
    if (!showAmount) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Subtotal',
                _currencyFormat.format(_finalAmount)),
            const SizedBox(height: 6),
            _summaryRow(
              _isFinalInvoice
                  ? 'GST (reconciled)'
                  : 'GST (5%)',
              _currencyFormat.format(_gstAmount),
            ),
            const Divider(height: 20, thickness: 1.5),
            _summaryRow(
              'Total Due',
              _currencyFormat.format(_total),
              bold: true,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText: _invoiceTypeLabels[_invoiceType],
        border: const OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildPoField() {
    return TextFormField(
      controller: _poNumberController,
      decoration: const InputDecoration(
        labelText: 'PO Number (optional)',
        border: OutlineInputBorder(),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Invoice' : 'New Invoice'),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white)),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _saveInvoice,
              child: Text(
                _isEditMode ? 'Update' : 'Save Draft',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_errorMessage!,
                            style:
                                const TextStyle(color: Colors.red)),
                      ),
                    _buildSectionHeader('Project'),
                    _buildProjectDropdown(),
                    const SizedBox(height: 12),
                    _buildClientField(),
                    const SizedBox(height: 12),
                    _buildContractSummary(),
                    _buildSectionHeader('Invoice Details'),
                    _buildInvoiceTypeDropdown(),
                    const SizedBox(height: 12),
                    _buildDateField(),
                    const SizedBox(height: 12),
                    _buildDescriptionField(),
                    _buildSectionHeader('Amount'),
                    _buildFinalInvoiceToggle(),
                    const SizedBox(height: 8),
                    _buildAmountField(),
                    const SizedBox(height: 16),
                    _buildGstSummary(),
                    _buildSectionHeader('Additional'),
                    _buildPoField(),
                    const SizedBox(height: 12),
                    _buildNotesField(),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveInvoice,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditMode
                          ? 'Update Invoice'
                          : 'Save as Draft'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
// end class: _CreateInvoiceScreenState
