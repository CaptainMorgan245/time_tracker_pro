// lib/create_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/invoice_service.dart';

// start class: CreateInvoiceScreen
class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

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
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Derived
  double get _subtotal =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
  double get _gstAmount => _subtotal * 0.05;
  double get _total => _subtotal + _gstAmount;

  static const Map<String, String> _invoiceTypeLabels = {
    'progress': 'Progress Draw',
    'chargeable': 'Chargeable Extra',
    'addendum': 'Addendum',
  };

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _loadProjects();
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
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load projects: $e';
        _isLoading = false;
      });
    }
  }

  void _onProjectSelected(Project? project) async {
    if (project == null) return;
    setState(() => _selectedProject = project);

    // Auto-select invoice type based on pricing model
    if (project.pricingModel == 'hourly') {
      setState(() => _invoiceType = 'chargeable');
    } else {
      setState(() => _invoiceType = 'progress');
    }

    // Load client for this project
    try {
      final client = await _invoiceRepository.getClientById(project.clientId);
      setState(() => _selectedProjectClient = client);
    } catch (e) {
      setState(() => _selectedProjectClient = null);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
    }
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
      final invoiceNumber =
      await _invoiceService.generateInvoiceNumber();

      final subtotal = _subtotal;
      final gstAmount = subtotal * 0.05;
      final total = subtotal + gstAmount;

      final invoice = Invoice(
        id: 0,
        invoiceNumber: invoiceNumber,
        invoiceDate: _invoiceDate,
        clientId: _selectedProject!.clientId,
        projectId: _selectedProject!.id!,
        projectAddress: _selectedProject!.location,
        labourSubtotal: _invoiceType == 'chargeable' ? subtotal : 0,
        materialsSubtotal: 0,
        materialsPickupCost: 0,
        otherCosts: _invoiceType == 'progress' || _invoiceType == 'addendum'
            ? subtotal
            : 0,
        otherCostsDescription: _descriptionController.text.trim().isEmpty
            ? _invoiceTypeLabels[_invoiceType]
            : _descriptionController.text.trim(),
        discountAmount: 0,
        discountPercent: 0,
        tax1Name: 'GST',
        tax1Rate: 5.0,
        tax1Amount: gstAmount,
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
        isPaid: false,
        amountPaid: null,
        paymentDate: null,
        paymentMethod: null,
        isDeleted: false,
        deletedReasonCode: null,
        deletedDate: null,
        deletedNotes: null,
        supersededByInvoiceId: null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isSent: false,
        invoiceType: _invoiceType,
      );

      await _invoiceService.createInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice $invoiceNumber created as draft.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // return true to trigger list refresh
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
      onChanged: _onProjectSelected,
      validator: (value) => value == null ? 'Please select a project' : null,
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
        child: Text(DateFormat('MMMM d, yyyy').format(_invoiceDate)),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: 'Amount (before GST) *',
        border: OutlineInputBorder(),
        prefixText: '\$ ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter an amount';
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) return 'Please enter a valid amount';
        return null;
      },
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

  Widget _buildGstSummary() {
    if (_subtotal <= 0) return const SizedBox.shrink();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_currencyFormat.format(_subtotal)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GST (5%):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_currencyFormat.format(_gstAmount)),
              ],
            ),
            const Divider(height: 20, thickness: 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Due:',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  _currencyFormat.format(_total),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        title: const Text('New Invoice'),
        actions: [
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
              child: const Text('Save Draft',
                  style: TextStyle(color: Colors.white)),
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
                      style: const TextStyle(color: Colors.red)),
                ),
              _buildSectionHeader('Project'),
              _buildProjectDropdown(),
              const SizedBox(height: 12),
              _buildClientField(),
              _buildSectionHeader('Invoice Details'),
              _buildInvoiceTypeDropdown(),
              const SizedBox(height: 12),
              _buildDateField(),
              const SizedBox(height: 12),
              _buildDescriptionField(),
              _buildSectionHeader('Amount'),
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
                label: const Text('Save as Draft'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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