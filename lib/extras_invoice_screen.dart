// lib/extras_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/invoice_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/invoice.dart';

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

  bool _isLoading = false;
  bool _isSaving = false;
  double _burdenRate = 0.0;
  double _discountAmount = 0.0;

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
      final db = await DatabaseHelperV2.instance.database;

      final projectsData = await db.query(
        'projects',
        where: 'is_completed = 0',
        orderBy: 'project_name ASC',
      );

      final clientsData = await db.query('clients', orderBy: 'name ASC');

      final settingsData = await db.rawQuery('SELECT burden_rate FROM settings LIMIT 1');
      double burdenRate = 0.0;
      if (settingsData.isNotEmpty) {
        burdenRate = (settingsData.first['burden_rate'] as num?)?.toDouble() ?? 0.0;
      }

      setState(() {
        _projects = projectsData;
        _clients = clientsData;
        _burdenRate = burdenRate;
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
        _timeEntries = List<Map<String, dynamic>>.from(records['timeEntries']);
        _materials = List<Map<String, dynamic>>.from(records['materials']);
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

    final start = DateTime.parse(te['start_time']);
    final end = te['end_time'] != null ? DateTime.parse(te['end_time']) : DateTime.now();
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
      (_selectedProject?['tax_rate'] as num?)?.toDouble() ?? 5.0;

  double get _gstAmount => _discountedSubtotal * (_taxRatePercent / 100.0);

  double get _invoiceTotal => _discountedSubtotal + _gstAmount;

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
        projectAddress: _selectedProject!['location'] ?? '',
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
          const SnackBar(content: Text('Extras invoice created successfully')),
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
        title: const Text('New Extras Invoice'),
      ),
      body: _isLoading && _projects.isEmpty
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
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No unbilled billable records found for this project.'),
                  ),
                )
              else
                ...allCostCodes.map((ccName) {
                  final timeForCC = groupedTime[ccName] ?? [];
                  final matsForCC = groupedMaterials[ccName] ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(
                            ccName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...timeForCC.map((te) {
                          final hours = _calculateTimeEntryHours(te);
                          final date = DateFormat('MMM d yyyy')
                              .format(DateTime.parse(te['start_time']));
                          return CheckboxListTile(
                            title: Text(
                                '${te['employee_name'] ?? 'Unknown'} - $date'),
                            subtitle: Text(
                                '${hours.toStringAsFixed(2)} hrs - ${te['work_details'] ?? 'No details'}'),
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
                        ...matsForCC.map((m) {
                          final date = DateFormat('MMM d yyyy')
                              .format(DateTime.parse(m['purchase_date']));
                          final cost = (m['cost'] as num).toDouble();
                          return CheckboxListTile(
                            title: Text('${m['item_name']} - $date'),
                            subtitle: Text(
                                '${m['vendor_or_subtrade'] ?? 'Unknown Vendor'} - ${_currencyFormat.format(cost)}'),
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
                    ),
                  );
                }),

              const SizedBox(height: 16),

              // ④ Narrative field
              TextField(
                controller: _narrativeController,
                decoration: const InputDecoration(
                  labelText: 'Invoice Narrative',
                  hintText: 'Describe the work performed (prints on invoice)',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 6,
              ),

              const SizedBox(height: 16),

              // ⑤ Totals summary card
              if (hasSelections) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Labour line
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Labour:'),
                            Text(
                                '${_currencyFormat.format(_labourSubtotal)} (${_totalHours.toStringAsFixed(2)} hrs)'),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Materials line
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Materials:'),
                            Text(_currencyFormat.format(_materialsSubtotal)),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Gross subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(_grossSubtotal),
                                style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),

                        const Divider(height: 20),

                        // Discount amount input
                        Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'Discount:',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _discountAmountController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: const InputDecoration(
                                  prefixText: '-\$',
                                  hintText: '0.00',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Discount description input (only shown when discount > 0)
                        if (_discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _discountDescriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Discount Description',
                              hintText: 'e.g. Fixed price adjustment — Demo & Hauling estimate',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                          ),
                        ],

                        const Divider(height: 20),

                        // Discounted subtotal (only shown when discount > 0)
                        if (_discountAmount > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discounted Subtotal:',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(_currencyFormat.format(_discountedSubtotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // GST line — always on discounted subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'GST (${_taxRatePercent.toStringAsFixed(1)}%):'),
                            Text(_currencyFormat.format(_gstAmount)),
                          ],
                        ),

                        const Divider(),

                        // Invoice total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Invoice Total:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _currencyFormat.format(_invoiceTotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ⑥ Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !hasSelections || _isSaving
                          ? null
                          : _createInvoice,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Text('Create Invoice'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _narrativeController.dispose();
    _discountAmountController.dispose();
    _discountDescriptionController.dispose();
    super.dispose();
  }
}