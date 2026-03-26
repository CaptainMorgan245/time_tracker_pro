// lib/extras_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/invoice_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/invoice.dart';
import 'package:time_tracker_pro/models/company_settings.dart';

class ExtrasInvoiceScreen extends StatefulWidget {
  const ExtrasInvoiceScreen({super.key});

  @override
  State<ExtrasInvoiceScreen> createState() => _ExtrasInvoiceScreenState();
}

class _ExtrasInvoiceScreenState extends State<ExtrasInvoiceScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final InvoiceService _invoiceService = InvoiceService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  bool _showClientDisambiguator = false;
  List<Map<String, dynamic>> _clients = [];
  Map<String, dynamic>? _selectedClient;

  List<Map<String, dynamic>> _timeEntries = [];
  List<Map<String, dynamic>> _materials = [];
  final Set<int> _selectedTimeEntryIds = {};
  final Set<int> _selectedMaterialIds = {};

  final TextEditingController _narrativeController = TextEditingController();
  final TextEditingController _discountAmountController = TextEditingController();
  final TextEditingController _discountDescriptionController = TextEditingController();
  final TextEditingController _projectAddressController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  double _burdenRate = 0.0;
  double _discountAmount = 0.0;
  double _defaultTaxRate = 5.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _discountAmountController.addListener(_onDiscountChanged);
  }

  void _onDiscountChanged() {
    final parsed = double.tryParse(_discountAmountController.text) ?? 0.0;
    setState(() {
      _discountAmount = parsed;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final projectsRows = await AppDatabase.instance.customSelect(
        'SELECT * FROM projects WHERE is_completed = 0 ORDER BY project_name ASC',
      ).get();
      final projectsData = projectsRows.map((r) => r.data).toList();

      final clientsRows = await AppDatabase.instance.customSelect(
        'SELECT * FROM clients ORDER BY name ASC',
      ).get();
      final clientsData = clientsRows.map((r) => r.data).toList();

      final settingsRows = await AppDatabase.instance.customSelect(
        'SELECT burden_rate FROM settings LIMIT 1',
      ).get();
      final settingsData = settingsRows.map((r) => r.data).toList();

      double burdenRate = 0.0;
      if (settingsData.isNotEmpty) {
        burdenRate = (settingsData.first['burden_rate'] as num?)?.toDouble() ?? 0.0;
      }

      final companySettings = await AppDatabase.instance.getCompanySettings();
      final defaultTaxRate = companySettings.defaultTax1Rate * 100.0;

      setState(() {
        _projects = projectsData;
        _clients = clientsData;
        _burdenRate = burdenRate;
        _defaultTaxRate = defaultTaxRate;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading initial data: $e')),
        );
      }
    }
  }

  void _onProjectSelected(Map<String, dynamic>? project) {
    if (project == null) return;

    final name = project['project_name'];
    final sameNameProjects = _projects.where((p) => p['project_name'] == name).toList();

    setState(() {
      _selectedProject = project;
      _projectAddressController.text = project['location'] ?? '';
      _selectedTimeEntryIds.clear();
      _selectedMaterialIds.clear();
      _timeEntries = [];
      _materials = [];

      if (sameNameProjects.length > 1) {
        _showClientDisambiguator = true;
        _selectedClient = null;
      } else {
        _showClientDisambiguator = false;
        _loadUnbilledRecords(project['id']);
      }
    });
  }

  Future<void> _loadUnbilledRecords(int projectId) async {
    setState(() => _isLoading = true);
    try {
      final records = await _invoiceRepository.fetchUnbilledBillableRecords(projectId);
      setState(() {
        _timeEntries = List<Map<String, dynamic>>.from(records['timeEntries']!);
        _materials = List<Map<String, dynamic>>.from(records['materials']!);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading unbilled records: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
    }
  }

  double _calculateTimeEntryHours(Map<String, dynamic> te) {
    if (te['final_billed_duration_seconds'] != null) {
      return (te['final_billed_duration_seconds'] as num).toDouble() / 3600.0;
    }

    if (te['end_time'] == null) {
      return 0.0;
    }

    final start = DateTime.parse(te['start_time']);
    final end = DateTime.parse(te['end_time']);
    final pausedSec = (te['paused_duration'] as num?)?.toDouble() ?? 0.0;

    final durationSec = end.difference(start).inSeconds.toDouble() - pausedSec;
    return durationSec / 3600.0;
  }

  double get _labourSubtotal {
    return _totalHours * _burdenRate;
  }

  double get _materialsSubtotal {
    double total = 0.0;
    for (var m in _materials) {
      if (_selectedMaterialIds.contains(m['id'])) {
        total += (m['cost'] as num).toDouble();
      }
    }
    return total;
  }

  double get _totalHours {
    double total = 0.0;
    for (var te in _timeEntries) {
      if (_selectedTimeEntryIds.contains(te['id'])) {
        total += _calculateTimeEntryHours(te);
      }
    }
    return total;
  }

  double get _grossSubtotal => _labourSubtotal + _materialsSubtotal;

  double get _discountedSubtotal {
    final discounted = _grossSubtotal - _discountAmount;
    return discounted < 0 ? 0.0 : discounted;
  }

  double get _taxRatePercent =>
      (_selectedProject?['tax_rate'] as num?)?.toDouble() ?? _defaultTaxRate;

  double get _gstAmount => _discountedSubtotal * (_taxRatePercent / 100.0);

  double get _invoiceTotal => _discountedSubtotal + _gstAmount;

  @override
  void dispose() {
    _narrativeController.dispose();
    _discountAmountController.dispose();
    _discountDescriptionController.dispose();
    _projectAddressController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    if (_selectedProject == null) return;

    // Validate discount doesn't exceed gross subtotal
    if (_discountAmount > _grossSubtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount cannot exceed the invoice subtotal.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final generatedNumber = await _invoiceService.generateInvoiceNumber();
      final discountDesc = _discountDescriptionController.text.trim();

      final invoice = Invoice(
        invoiceNumber: generatedNumber,
        invoiceDate: DateTime.now(),
        clientId: _selectedProject!['client_id'],
        projectId: _selectedProject!['id'],
        projectAddress: _projectAddressController.text.trim(),
        labourSubtotal: _labourSubtotal,
        materialsSubtotal: _materialsSubtotal,
        discountAmount: _discountAmount,
        discountDescription: discountDesc.isNotEmpty ? discountDesc : null,
        tax1Name: 'GST',
        tax1Rate: _taxRatePercent,
        tax1Amount: _gstAmount,
        subtotal: _discountedSubtotal,
        totalAmount: _invoiceTotal,
        invoiceType: 'extras',
        notes: _narrativeController.text.trim(),
        isPaid: false,
        isDeleted: false,
        isSent: false,
      );

      final newId = await _invoiceRepository.insertInvoice(invoice);

      await _invoiceRepository.markRecordsAsBilled(
        invoiceId: newId,
        timeEntryIds: _selectedTimeEntryIds.toList(),
        materialIds: _selectedMaterialIds.toList(),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time & Materials invoice created successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating invoice: $e')),
        );
      }
    }
  }

  String _getProjectDisplayName(Map<String, dynamic> project) {
    final name = project['project_name'];
    final sameNameProjects = _projects.where((p) => p['project_name'] == name).toList();
    if (sameNameProjects.length > 1) {
      final client = _clients.firstWhere(
              (c) => c['id'] == project['client_id'],
          orElse: () => {'name': 'Unknown'});
      return '$name (${client['name']})';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedTime = {};
    for (var te in _timeEntries) {
      final ccName = te['cost_code_name'] as String? ?? 'Uncategorized';
      groupedTime.putIfAbsent(ccName, () => []).add(te);
    }

    final Map<String, List<Map<String, dynamic>>> groupedMaterials = {};
    for (var m in _materials) {
      final ccName = m['cost_code_name'] as String? ?? 'Uncategorized';
      groupedMaterials.putIfAbsent(ccName, () => []).add(m);
    }

    final allCostCodes = {...groupedTime.keys, ...groupedMaterials.keys}.toList()..sort();

    final bool hasSelections =
        _selectedTimeEntryIds.isNotEmpty || _selectedMaterialIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Time & Materials Invoice'),
      ),
      body: SelectionArea(
        child: _isLoading && _projects.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ① Project dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Select Project'),
                value: _selectedProject?['id'],
                items: _projects.map((p) {
                  return DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text(_getProjectDisplayName(p)),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final match = _projects.firstWhere((p) => p['id'] == id);
                  _onProjectSelected(match);
                },
              ),

              const SizedBox(height: 12),
              TextField(
                controller: _projectAddressController,
                decoration: const InputDecoration(
                  labelText: 'Site Address',
                  hintText: 'Enter site address for this invoice',
                  border: OutlineInputBorder(),
                ),
              ),

              // ② Client disambiguator
              if (_showClientDisambiguator) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Select Client'),
                  value: _selectedClient?['id'],
                  items: _clients.where((c) {
                    return _projects.any((p) =>
                    p['project_name'] == _selectedProject!['project_name'] &&
                        p['client_id'] == c['id']);
                  }).map((c) {
                    return DropdownMenuItem<int>(
                        value: c['id'] as int, child: Text(c['name']));
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final client = _clients.firstWhere((c) => c['id'] == id);
                    setState(() {
                      _selectedClient = client;
                      final project = _projects.firstWhere((p) =>
                      p['project_name'] == _selectedProject!['project_name'] &&
                          p['client_id'] == id);
                      _selectedProject = project;
                      _projectAddressController.text = project['location'] ?? '';
                      _loadUnbilledRecords(project['id']);
                    });
                  },
                ),
              ],

              const SizedBox(height: 16),

              // ③ Unbilled records
              if (_selectedProject != null) ...[
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_timeEntries.isEmpty && _materials.isEmpty)
                  const Center(child: Text('No unbilled records for this project.'))
                else ...[
                  const Text('Select records to include:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...allCostCodes.map((cc) {
                    final ccTime = groupedTime[cc] ?? [];
                    final ccMat = groupedMaterials[cc] ?? [];
                    return ExpansionTile(
                      title: Text(cc),
                      children: [
                        ...ccTime.map((te) {
                          final hours = _calculateTimeEntryHours(te);
                          final date = DateFormat('MMM d').format(DateTime.parse(te['start_time']));
                          return CheckboxListTile(
                            title: Text('$date: ${te['employee_name'] ?? 'Unknown'}'),
                            subtitle: Text('${hours.toStringAsFixed(2)} hrs - ${te['work_details'] ?? ''}'),
                            value: _selectedTimeEntryIds.contains(te['id']),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedTimeEntryIds.add(te['id']);
                                } else {
                                  _selectedTimeEntryIds.remove(te['id']);
                                }
                              });
                            },
                          );
                        }),
                        ...ccMat.map((m) {
                          final cost = (m['cost'] as num).toDouble();
                          final date = DateFormat('MMM d').format(DateTime.parse(m['purchase_date']));
                          return CheckboxListTile(
                            title: Text('$date: ${m['item_name']}'),
                            subtitle: Text('${_currencyFormat.format(cost)} - ${m['description'] ?? ''}'),
                            value: _selectedMaterialIds.contains(m['id']),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMaterialIds.add(m['id']);
                                } else {
                                  _selectedMaterialIds.remove(m['id']);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    );
                  }),
                ],

                const Divider(height: 32),

                // ④ Invoice details
                const Text('Invoice Details', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _narrativeController,
                  decoration: const InputDecoration(
                    labelText: 'Work Description / Narrative',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _discountDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Discount Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _discountAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Discount (\$)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // ⑤ Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Hours:', _totalHours.toStringAsFixed(2)),
                      _buildSummaryRow('Labour Total (@ ${_currencyFormat.format(_burdenRate)}/hr):',
                          _currencyFormat.format(_labourSubtotal)),
                      _buildSummaryRow('Materials Total:', _currencyFormat.format(_materialsSubtotal)),
                      const Divider(),
                      _buildSummaryRow('Gross Subtotal:', _currencyFormat.format(_grossSubtotal)),
                      if (_discountAmount > 0)
                        _buildSummaryRow('Discount:', '- ${_currencyFormat.format(_discountAmount)}',
                            color: Colors.red),
                      _buildSummaryRow('Taxable Subtotal:', _currencyFormat.format(_discountedSubtotal)),
                      _buildSummaryRow('GST (${_taxRatePercent.toStringAsFixed(1)}%):',
                          _currencyFormat.format(_gstAmount)),
                      const Divider(),
                      _buildSummaryRow('Invoice Total:', _currencyFormat.format(_invoiceTotal),
                          isTotal: true),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: (hasSelections && !_isSaving) ? _createInvoice : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Create Time & Materials Invoice'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 18 : 14,
              )),
          Text(value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 18 : 14,
                color: color,
              )),
        ],
      ),
    );
  }
}
