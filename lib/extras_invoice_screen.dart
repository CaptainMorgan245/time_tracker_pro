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
  const ExtrasInvoiceScreen({super.key, this.existingInvoice});
  final Invoice? existingInvoice;

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
    AppDatabase.instance.databaseNotifier.addListener(_loadUnbilledRecords);
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

      // Pre-populate fields if editing
      if (widget.existingInvoice != null) {
        final inv = widget.existingInvoice!;

        // Pre-populate text fields
        _narrativeController.text = inv.workDescription ?? inv.notes ?? '';
        _discountDescriptionController.text = inv.discountDescription ?? '';
        _discountAmountController.text = inv.discountAmount > 0
            ? inv.discountAmount.toStringAsFixed(2)
            : '';

        // Find and select matching project
        final matchingProject = projectsData.firstWhere(
          (p) => p['id'] == inv.projectId,
          orElse: () => <String, dynamic>{},
        );
        if (matchingProject.isNotEmpty) {
          _onProjectSelected(matchingProject);
        }

        // Fetch previously billed records for this invoice
        final billedTimeRows = await AppDatabase.instance.customSelect(
          'SELECT id FROM time_entries WHERE invoice_id = ?',
          variables: [Variable.withInt(inv.id!)],
        ).get();
        final billedMatRows = await AppDatabase.instance.customSelect(
          'SELECT id FROM materials WHERE invoice_id = ?',
          variables: [Variable.withInt(inv.id!)],
        ).get();

        // Fetch full billed records to display in the list
        final billedTimeFullRows = await AppDatabase.instance.customSelect(
          '''SELECT t.*, cc.name as cost_code_name, e.name as employee_name
             FROM time_entries t
             LEFT JOIN cost_codes cc ON t.cost_code_id = cc.id
             LEFT JOIN employees e ON t.employee_id = e.id
             WHERE t.invoice_id = ?''',
          variables: [Variable.withInt(inv.id!)],
        ).get();

        final billedMatFullRows = await AppDatabase.instance.customSelect(
          '''SELECT m.*, cc.name as cost_code_name
             FROM materials m
             LEFT JOIN cost_codes cc ON m.cost_code_id = cc.id
             WHERE m.invoice_id = ?''',
          variables: [Variable.withInt(inv.id!)],
        ).get();

        setState(() {
          _selectedTimeEntryIds.addAll(
            billedTimeRows.map((r) => (r.data['id'] as num).toInt())
          );
          _selectedMaterialIds.addAll(
            billedMatRows.map((r) => (r.data['id'] as num).toInt())
          );
          
          final billedTimeEntries = billedTimeFullRows.map((r) => r.data).toList();
          final billedMaterials = billedMatFullRows.map((r) => r.data).toList();

          // Merge: Only add records that are not already in the list
          final existingTimeIds = _timeEntries.map((te) => te['id'] as int).toSet();
          for (var te in billedTimeEntries) {
            if (!existingTimeIds.contains(te['id'] as int)) {
              _timeEntries.add(te);
            }
          }

          final existingMaterialIds = _materials.map((m) => m['id'] as int).toSet();
          for (var m in billedMaterials) {
            if (!existingMaterialIds.contains(m['id'] as int)) {
              _materials.add(m);
            }
          }
        });
      }
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
      _projectAddressController.text = _buildProjectAddress(Project.fromMap(project));
      _selectedTimeEntryIds.clear();
      _selectedMaterialIds.clear();
      _timeEntries = [];
      _materials = [];
      _showClientDisambiguator = sameNameProjects.length > 1;
      if (sameNameProjects.length > 1) {
        _selectedClient = null;
      }
    });
    if (sameNameProjects.length <= 1) {
      _loadUnbilledRecords(project['id']);
    }
  }

  Future<void> _loadUnbilledRecords([int? projectId]) async {
    final targetId = projectId ?? _selectedProject?['id'];
    if (targetId == null) return;
    
    if (mounted) setState(() => _isLoading = true);
    try {
      final records = await _invoiceRepository.fetchUnbilledBillableRecords(targetId);
      if (mounted) {
        setState(() {
          final newTimeEntries = List<Map<String, dynamic>>.from(records['timeEntries']!);
          final newMaterials = List<Map<String, dynamic>>.from(records['materials']!);

          // Merge: Only add records that are not already in the list
          final existingTimeIds = _timeEntries.map((te) => te['id'] as int).toSet();
          for (var te in newTimeEntries) {
            if (!existingTimeIds.contains(te['id'] as int)) {
              _timeEntries.add(te);
            }
          }

          final existingMaterialIds = _materials.map((m) => m['id'] as int).toSet();
          for (var m in newMaterials) {
            if (!existingMaterialIds.contains(m['id'] as int)) {
              _materials.add(m);
            }
          }
          
          _isLoading = false;
        });
      }
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
    AppDatabase.instance.databaseNotifier.removeListener(_loadUnbilledRecords);
    _narrativeController.dispose();
    _discountAmountController.dispose();
    _discountDescriptionController.dispose();
    _projectAddressController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    if (_selectedProject == null) return;
    if (_discountAmount > _grossSubtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount cannot exceed the invoice subtotal.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final discountDesc = _discountDescriptionController.text.trim();
      final isEditMode = widget.existingInvoice != null;

      if (isEditMode) {
        // Update existing invoice
        final updated = widget.existingInvoice!.copyWith(
          projectAddress: _projectAddressController.text.trim(),
          labourSubtotal: _labourSubtotal,
          materialsSubtotal: _materialsSubtotal,
          discountAmount: _discountAmount,
          discountDescription: discountDesc.isNotEmpty ? discountDesc : null,
          tax1Amount: _gstAmount,
          subtotal: _discountedSubtotal,
          totalAmount: _invoiceTotal,
          workDescription: _narrativeController.text.trim(),
          notes: null,
        );
        await _invoiceRepository.updateInvoice(updated);

        // Reset all previously billed records for this invoice
        await AppDatabase.instance.customUpdate(
          'UPDATE time_entries SET is_billed = 0, invoice_id = NULL WHERE invoice_id = ?',
          variables: [Variable.withInt(widget.existingInvoice!.id!)],
          updates: {},
        );
        await AppDatabase.instance.customUpdate(
          'UPDATE materials SET is_billed = 0, invoice_id = NULL WHERE invoice_id = ?',
          variables: [Variable.withInt(widget.existingInvoice!.id!)],
          updates: {},
        );

        // Re-mark selected records as billed
        await _invoiceRepository.markRecordsAsBilled(
          invoiceId: widget.existingInvoice!.id!,
          timeEntryIds: _selectedTimeEntryIds.toList(),
          materialIds: _selectedMaterialIds.toList(),
        );
      } else {
        // Create new invoice
        final generatedNumber = await _invoiceService.generateInvoiceNumber();
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
          workDescription: _narrativeController.text.trim(),
          notes: null,
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
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode
              ? 'Invoice updated successfully'
              : 'Time & Materials invoice created successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
        );
      }
    }
  }

  String _buildProjectAddress(Project project) {
    final parts = <String>[];
    if ((project.streetAddress ?? '').isNotEmpty) {
      parts.add(project.streetAddress!);
    }
    final cityLine = <String>[];
    if ((project.city ?? '').isNotEmpty) cityLine.add(project.city!);
    if ((project.region ?? '').isNotEmpty) cityLine.add(project.region!);
    if ((project.postalCode ?? '').isNotEmpty) cityLine.add(project.postalCode!);
    if (cityLine.isNotEmpty) parts.add(cityLine.join('  '));
    return parts.join('\n');
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
        title: Text(widget.existingInvoice != null
            ? 'Edit Invoice'
            : 'New Time & Materials Invoice'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (hasSelections && !_isSaving) ? _createInvoice : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const CircularProgressIndicator()
                : Text(widget.existingInvoice != null
                ? 'Update Invoice'
                : 'Create Time & Materials Invoice'),
          ),
        ),
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
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
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
                      _projectAddressController.text = _buildProjectAddress(Project.fromMap(project));
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
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
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
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
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
                        textInputAction: TextInputAction.done,
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
