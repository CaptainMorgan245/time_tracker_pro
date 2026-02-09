// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:intl/intl.dart';

class CostRecordFormTopRow extends StatelessWidget {
  final GlobalKey<CostRecordFormState> formStateKey;
  final ValueNotifier<List<Project>> filteredProjectsNotifier;
  final ValueNotifier<List<String>> expenseCategoriesNotifier;
  final ValueNotifier<bool> isCompanyExpenseNotifier;
  final bool showCompletedProjects;
  final Function(bool showCompleted) onProjectFilterToggle;
  final String currentItemName;

  const CostRecordFormTopRow({
    super.key,
    required this.formStateKey,
    required this.filteredProjectsNotifier,
    required this.expenseCategoriesNotifier,
    required this.isCompanyExpenseNotifier,
    required this.showCompletedProjects,
    required this.onProjectFilterToggle,
    required this.currentItemName,
  });

  @override
  Widget build(BuildContext context) {
    const EdgeInsets consistentContentPadding = EdgeInsets.fromLTRB(12, 20, 8, 10);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            flex: 4,
            child: ValueListenableBuilder<bool>(
              valueListenable: isCompanyExpenseNotifier,
              builder: (context, isCompanyExpense, _) {
                return ValueListenableBuilder<List<Project>>(
                  valueListenable: filteredProjectsNotifier,
                  builder: (context, projects, _) {
                    final isProjectDropdownEnabled = !isCompanyExpense;
                    final currentProjectId = isCompanyExpense
                        ? 0
                        : formStateKey.currentState?.selectedProjectId;

                    return DropdownButtonFormField<int?>(
                      decoration: InputDecoration(
                        labelText: 'Select Project',
                        suffixIcon: isProjectDropdownEnabled ? const Text('*') : null,
                        contentPadding: consistentContentPadding,
                      ),
                      isDense: true,
                      value: currentProjectId,
                      onChanged: isProjectDropdownEnabled
                          ? (int? newValue) {
                        if (newValue != null) {
                          formStateKey.currentState?.setSelectedProjectId(newValue);
                        }
                      }
                          : null,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('-- Select Project --', style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        ...projects.map((project) {
                          final displayName = project.isInternal
                              ? 'Internal Company Project'
                              : project.projectName;
                          return DropdownMenuItem<int?>(
                            value: project.id,
                            child: Text(displayName, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 5,
            child: TextFormField(
              key: ValueKey('itemName_${currentItemName}_${formStateKey.hashCode}'),
              initialValue: currentItemName,
              decoration: InputDecoration(
                labelText: 'Item Names',
                contentPadding: consistentContentPadding,
                isDense: true,
              ),
              onChanged: (value) {
                formStateKey.currentState?.setItemName(value);
              },
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 3,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: expenseCategoriesNotifier,
              builder: (context, categories, _) {
                final currentCategory = formStateKey.currentState?.selectedExpenseCategory;
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Expense Category *',
                    contentPadding: consistentContentPadding,
                  ),
                  value: currentCategory,
                  items: categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                  onChanged: (String? newValue) {
                    formStateKey.currentState?.setState(() {
                      formStateKey.currentState!.selectedExpenseCategory = newValue;
                      formStateKey.currentState!.isFuelCategory = (newValue == 'Fuel');
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: isCompanyExpenseNotifier,
                        builder: (context, isCompanyExpense, _) {
                          return Checkbox(
                            value: isCompanyExpense,
                            onChanged: (bool? newValue) {
                              isCompanyExpenseNotifier.value = newValue ?? false;
                              if (isCompanyExpenseNotifier.value) {
                                formStateKey.currentState?.setSelectedProjectId(0);
                              }
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          const SizedBox(width: 2),
                          Tooltip(
                            message: 'Sets project to Internal and locks dropdown for company vehicle expenses.',
                            triggerMode: TooltipTriggerMode.tap,
                            child: const Icon(Icons.help_outline, size: 16, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: showCompletedProjects,
                        onChanged: (bool? newValue) {
                          onProjectFilterToggle(newValue ?? false);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Comp.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          const SizedBox(width: 2),
                          Tooltip(
                            message: 'Filters list to show only projects marked as "Completed".',
                            triggerMode: TooltipTriggerMode.tap,
                            child: const Icon(Icons.help_outline, size: 16, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CostEntryScreen extends StatefulWidget {
  const CostEntryScreen({super.key});

  @override
  State<CostEntryScreen> createState() => _CostEntryScreenState();
}

class _CostEntryScreenState extends State<CostEntryScreen> {
  final _formStateKey = GlobalKey<CostRecordFormState>();
  final _projectRepo = ProjectRepository();
  final _dbHelper = DatabaseHelperV2.instance;
  final dbNotifier = DatabaseHelperV2.instance.databaseNotifier;

  bool _isLoading = true;
  bool _showCompletedProjects = false;

  final ValueNotifier<List<Project>> _filteredProjectsNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _expenseCategoriesNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _vendorsNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _vehicleDesignationsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isCompanyExpenseNotifier = ValueNotifier(false);

  List<Project> _allProjects = [];
  int? _selectedProjectIdForFiltering;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    dbNotifier.addListener(_loadAllData);
  }

  @override
  void dispose() {
    dbNotifier.removeListener(_loadAllData);
    _filteredProjectsNotifier.dispose();
    _expenseCategoriesNotifier.dispose();
    _vendorsNotifier.dispose();
    _vehicleDesignationsNotifier.dispose();
    _isCompanyExpenseNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final settingsMap = await db.query('settings', where: 'id = ?', whereArgs: [1]);
      final settings = settingsMap.isNotEmpty ? SettingsModel.fromMap(settingsMap.first) : SettingsModel();

      final dataFutures = [_projectRepo.getProjects(), DatabaseHelperV2.instance.getExpenseCategoriesV2()];
      final results = await Future.wait(dataFutures);
      _allProjects = results[0] as List<Project>;
      final categories = results[1] as List<ExpenseCategory>;

      if (!mounted) return;
      _expenseCategoriesNotifier.value = categories.map((c) => c.name).toList();
      _vendorsNotifier.value = List<String>.from(settings.vendors);
      _vehicleDesignationsNotifier.value = List<String>.from(settings.vehicleDesignations);

      if (!_allProjects.any((p) => p.id == 0)) {
        _allProjects.insert(0, Project(id: 0, projectName: 'Internal Company Project', clientId: 0, isInternal: true, pricingModel: 'hourly'));
      }

      _applyProjectFilter(_showCompletedProjects);
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyProjectFilter(bool showCompleted) {
    setState(() {
      _showCompletedProjects = showCompleted;
      _selectedProjectIdForFiltering = null;
    });
    if (showCompleted) {
      _filteredProjectsNotifier.value = _allProjects.where((p) => p.isCompleted).toList();
    } else {
      _filteredProjectsNotifier.value = _allProjects.where((p) => !p.isCompleted || p.isInternal).toList();
    }
  }

  void _showEditModal(JobMaterials record) {
    final editFormKey = GlobalKey<CostRecordFormState>();
    final editCompanyExpenseNotifier = ValueNotifier<bool>(record.isCompanyExpense);
    final editProjectsNotifier = ValueNotifier<List<Project>>(_allProjects);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text("Edit Record"),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Vehicle checkbox row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: editCompanyExpenseNotifier,
                            builder: (context, isCompanyExpense, _) {
                              return Checkbox(
                                value: isCompanyExpense,
                                onChanged: (bool? newValue) {
                                  editCompanyExpenseNotifier.value = newValue ?? false;
                                  if (editCompanyExpenseNotifier.value) {
                                    editFormKey.currentState?.setSelectedProjectId(0);
                                  }
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              );
                            },
                          ),
                          const Text('Vehicle Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Sets project to Internal and locks dropdown for company vehicle expenses.',
                            triggerMode: TooltipTriggerMode.tap,
                            child: Icon(Icons.help_outline, size: 16, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                CostRecordForm(
                  key: editFormKey,
                  availableProjectsNotifier: editProjectsNotifier,
                  expenseCategoriesNotifier: _expenseCategoriesNotifier,
                  vendorsNotifier: _vendorsNotifier,
                  vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                  onAddExpense: (expense, isEdit) async {
                    await _handleCostSubmission(expense, isEdit);
                    if (context.mounted) Navigator.pop(context);
                  },
                  onProjectFilterToggle: (_) {},
                  onClearForm: () => Navigator.pop(context),
                  isEditing: true,
                  onCompanyExpenseToggle: editCompanyExpenseNotifier,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Populate form data after dialog builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editFormKey.currentState != null) {
        editFormKey.currentState!.populateForm(record);
      }
    });
  }

  void _handleClearOrCancel() {
    _formStateKey.currentState?.resetForm();
    setState(() {
      _isCompanyExpenseNotifier.value = false;
      _selectedProjectIdForFiltering = null;
    });
  }

  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    if (isEditing) {
      await DatabaseHelperV2.instance.updateMaterialV2(expense);
    } else {
      await DatabaseHelperV2.instance.addMaterialV2(expense);
    }
    DatabaseHelperV2.instance.databaseNotifier.value++;
    if (!isEditing) _handleClearOrCancel();
  }

  Future<void> _deleteExpense(int id) async {
    await DatabaseHelperV2.instance.deleteRecordV2(id: id, fromTable: 'materials');
    DatabaseHelperV2.instance.databaseNotifier.value++;
  }

  String _getProjectNameById(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).projectName;
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: CostRecordFormTopRow(
                formStateKey: _formStateKey,
                filteredProjectsNotifier: _filteredProjectsNotifier,
                expenseCategoriesNotifier: _expenseCategoriesNotifier,
                isCompanyExpenseNotifier: _isCompanyExpenseNotifier,
                showCompletedProjects: _showCompletedProjects,
                onProjectFilterToggle: _applyProjectFilter,
                currentItemName: _formStateKey.currentState?.getCurrentItemName() ?? '',
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: CostRecordForm(
                key: _formStateKey,
                availableProjectsNotifier: _filteredProjectsNotifier,
                expenseCategoriesNotifier: _expenseCategoriesNotifier,
                vendorsNotifier: _vendorsNotifier,
                vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                onAddExpense: _handleCostSubmission,
                onProjectFilterToggle: _applyProjectFilter,
                onClearForm: _handleClearOrCancel,
                isEditing: false,
                onCompanyExpenseToggle: _isCompanyExpenseNotifier,
              ),
            ),
            const Divider(),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: dbNotifier,
                builder: (context, _, __) {
                  return FutureBuilder<List<JobMaterials>>(
                    future: DatabaseHelperV2.instance.getCostEntryMaterials(
                      _showCompletedProjects,
                      _allProjects,
                      selectedProjectId: _selectedProjectIdForFiltering,
                    ),
                    builder: (context, snapshot) {
                      final records = snapshot.data ?? [];
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final projectName = _getProjectNameById(record.projectId);
                          final vendorName = record.vendorOrSubtrade ?? 'Unknown Vendor';
                          final costAmount = NumberFormat.currency(locale: 'en_US', symbol: '\$').format(record.cost);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.receipt, color: Colors.green),
                              title: Text(
                                '${DateFormat('MMM dd, yyyy').format(record.purchaseDate)} | Project: $projectName | $costAmount',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('Vendor: $vendorName | Category: ${record.expenseCategory ?? 'N/A'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                    onPressed: () => _showEditModal(record),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    onPressed: () => _deleteExpense(record.id!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}