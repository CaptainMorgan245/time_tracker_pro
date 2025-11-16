// lib/cost_entry_screen.dart (COMPLETE FILE - Fixed with Integer Project IDs)

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:intl/intl.dart';

// Separate sticky top row widget
class CostRecordFormTopRow extends StatelessWidget {
  final GlobalKey<CostRecordFormState> formStateKey;
  final ValueNotifier<List<Project>> filteredProjectsNotifier;
  final ValueNotifier<List<String>> expenseCategoriesNotifier;
  final ValueNotifier<List<String>> vendorsNotifier;
  final ValueNotifier<List<String>> vehicleDesignationsNotifier;
  final ValueNotifier<bool> isCompanyExpenseNotifier;
  final bool showCompletedProjects;
  final Function(bool showCompleted) onProjectFilterToggle;
  final String currentItemName;

  const CostRecordFormTopRow({
    super.key,
    required this.formStateKey,
    required this.filteredProjectsNotifier,
    required this.expenseCategoriesNotifier,
    required this.vendorsNotifier,
    required this.vehicleDesignationsNotifier,
    required this.isCompanyExpenseNotifier,
    required this.showCompletedProjects,
    required this.onProjectFilterToggle,
    required this.currentItemName,
  });

  @override
  Widget build(BuildContext context) {
    // Define consistent padding for all form fields
    const EdgeInsets consistentContentPadding = EdgeInsets.fromLTRB(12, 20, 8, 10);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FIXED: Project dropdown now uses integer IDs
          Flexible(
            flex: 4,
            child: ValueListenableBuilder<List<Project>>(
              valueListenable: filteredProjectsNotifier,
              builder: (context, projects, _) {
                final isProjectDropdownEnabled = !isCompanyExpenseNotifier.value;
                final currentProjectId = isCompanyExpenseNotifier.value
                    ? 0  // Internal project ID
                    : formStateKey.currentState?.selectedProjectId;

                return DropdownButtonFormField<int>(
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
                      // Update parent's filtering variable
                      final parentState = formStateKey.currentContext?.findAncestorStateOfType<_CostEntryScreenState>();
                      parentState?._updateSelectedProjectFilter(newValue);
                    }
                  }
                      : null,
                  items: projects.map((project) {
                    final displayName = project.isInternal
                        ? 'Internal Company Project'
                        : project.projectName;
                    return DropdownMenuItem<int>(
                      value: project.id,
                      child: Text(displayName, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(width: 16),

          // Item Names field - editable text field
          Flexible(
            flex: 5,
            child: TextFormField(
              key: ValueKey(currentItemName),
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

          // Expense Category
          Flexible(
            flex: 3,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: expenseCategoriesNotifier,
              builder: (context, categories, _) {
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Expense Category *',
                    contentPadding: consistentContentPadding,
                  ),
                  value: formStateKey.currentState?.selectedExpenseCategory,
                  items: categories.map((c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c)
                  )).toList(),
                  onChanged: (String? newValue) {
                    // ignore: invalid_use_of_protected_member
                    formStateKey.currentState?.setState(() {
                      formStateKey.currentState!.selectedExpenseCategory = newValue;
                      formStateKey.currentState!.isFuelCategory = newValue == 'Fuel';
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(width: 16),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0.0),
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
                                  // FIXED: Set by ID instead of object
                                  formStateKey.currentState?.setSelectedProjectId(0);
                                }
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          },
                        ),
                        const Text(
                          'Vehicle Expense',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
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
                        const Text(
                          'Show Completed',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
  final _scrollController = ScrollController();

  final _projectRepo = ProjectRepository();
  final _settingsService = SettingsService.instance;
  final dbNotifier = DatabaseHelperV2.instance.databaseNotifier;

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isFormCollapsed = false;
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
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final shouldBeCollapsed = _scrollController.offset > 50.0;
    if (shouldBeCollapsed != _isFormCollapsed) {
      setState(() {
        _isFormCollapsed = shouldBeCollapsed;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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
      final dataFutures = [
        _projectRepo.getProjects(),
        DatabaseHelperV2.instance.getExpenseCategoriesV2(),
        _settingsService.loadSettings(),
      ];
      final results = await Future.wait(dataFutures);
      final allProjects = results[0] as List<Project>;
      final categories = results[1] as List<ExpenseCategory>;
      final settings = results[2] as SettingsModel;

      _allProjects = allProjects;

      if (!mounted) return;

      _expenseCategoriesNotifier.value = categories.map((c) => c.name).toList();
      _vendorsNotifier.value = List<String>.from(settings.vendors);
      _vehicleDesignationsNotifier.value = List<String>.from(settings.vehicleDesignations);

      final internalProjectExists = _allProjects.any((p) => p.id == 0);
      if (!internalProjectExists) {
        _allProjects.insert(0, Project(
          id: 0,
          projectName: 'Internal Company Project',
          clientId: 0,
          isInternal: true,
          pricingModel: 'hourly',
        ));
      }

      _applyProjectFilter(_showCompletedProjects);

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dependency data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyProjectFilter(bool showCompleted) {
    setState(() {
      _showCompletedProjects = showCompleted;
    });

    if (showCompleted) {
      _filteredProjectsNotifier.value = _allProjects.where((p) => p.isCompleted).toList();
    } else {
      _filteredProjectsNotifier.value = _allProjects.where((p) => !p.isCompleted || p.isInternal).toList();
    }

    // Reset form with first available project from NEW filtered list
    if (_filteredProjectsNotifier.value.isNotEmpty) {
      final firstNonInternal = _filteredProjectsNotifier.value.firstWhere(
              (p) => !p.isInternal,
          orElse: () => _filteredProjectsNotifier.value.first
      );
      _formStateKey.currentState?.selectedProjectId = firstNonInternal.id;
      _selectedProjectIdForFiltering = firstNonInternal.id;
    }
  }

  void _updateSelectedProjectFilter(int projectId) {
    setState(() {
      _selectedProjectIdForFiltering = projectId;
    });
  }

  void _populateFormFromExpense(JobMaterials expense) {
    _isCompanyExpenseNotifier.value = expense.isCompanyExpense;

    setState(() {
      _isEditing = true;
      _isFormCollapsed = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _formStateKey.currentState?.populateForm(expense);
        _formStateKey.currentState?.focusFirstField();
      });
    });
  }

  Future<void> _handleDescriptionInput() async {
    final isEditing = _isEditing;

    final currentItemName = isEditing
        ? (_formStateKey.currentState?.getCurrentItemName() ?? '')
        : '';

    final newDescription = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final textController = TextEditingController(text: currentItemName);
        return AlertDialog(
          title: const Text('Enter Item Names'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Item Names',
              hintText: 'e.g., 5 Gallons Diesel, Lunch for Crew',
            ),
            maxLines: 3,
            minLines: 1,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(textController.text),
            ),
          ],
        );
      },
    );

    if (newDescription != null) {
      _formStateKey.currentState?.setItemName(newDescription);

      if (_isEditing) {
        _formStateKey.currentState?.triggerSubmit();
      }
    }
  }

  void _handleClearOrCancel() {
    _formStateKey.currentState?.resetForm();
    if (mounted) {
      setState(() {
        _isEditing = false;
        _isCompanyExpenseNotifier.value = false;
      });
    }
  }

  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    try {
      if (isEditing) {
        await DatabaseHelperV2.instance.updateMaterialV2(expense);
      } else {
        await DatabaseHelperV2.instance.addMaterialV2(expense);
      }
      if (mounted) {
        if (!isEditing) {
          _handleClearOrCancel();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense ${isEditing ? 'updated' : 'added'} successfully.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting expense: $e')),
        );
      }
    }
  }

  Future<void> _deleteExpense(int id) async {
    try {
      await DatabaseHelperV2.instance.deleteRecordV2(id: id, fromTable: 'materials');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting expense: $e')),
        );
      }
    }
  }

  String _getProjectNameById(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).projectName;
    } catch (_) {
      return 'Unknown Project';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItemNameForDisplay = _formStateKey.currentState?.getCurrentItemName() ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Card(
              elevation: 2.0,
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: CostRecordFormTopRow(
                formStateKey: _formStateKey,
                filteredProjectsNotifier: _filteredProjectsNotifier,
                expenseCategoriesNotifier: _expenseCategoriesNotifier,
                vendorsNotifier: _vendorsNotifier,
                vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                isCompanyExpenseNotifier: _isCompanyExpenseNotifier,
                showCompletedProjects: _showCompletedProjects,
                onProjectFilterToggle: _applyProjectFilter,
                currentItemName: currentItemNameForDisplay,
              ),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isFormCollapsed ? 0 : null,
              child: _isFormCollapsed
                  ? const SizedBox.shrink()
                  : Card(
                elevation: 2.0,
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: CostRecordForm(
                  key: _formStateKey,
                  availableProjectsNotifier: _filteredProjectsNotifier,
                  expenseCategoriesNotifier: _expenseCategoriesNotifier,
                  vendorsNotifier: _vendorsNotifier,
                  vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                  onAddExpense: _handleCostSubmission,
                  onProjectFilterToggle: _applyProjectFilter,
                  onClearForm: _handleClearOrCancel,
                  isEditing: _isEditing,
                  onCompanyExpenseToggle: _isCompanyExpenseNotifier,
                  isCollapsed: false,
                  onCollapseToggle: () {},
                ),
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: dbNotifier,
                builder: (context, _, __) => FutureBuilder<List<JobMaterials>>(
                  key: ValueKey('${_showCompletedProjects}_${_selectedProjectIdForFiltering}'),
                  future: DatabaseHelperV2.instance.getCostEntryMaterials(
                    _showCompletedProjects,
                    _allProjects,
                    selectedProjectId: _selectedProjectIdForFiltering,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 200,
                        child: Center(child: Text('Error: ${snapshot.error}')),
                      );
                    }
                    final records = snapshot.data ?? [];
                    if (records.isEmpty) {
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text("No cost records found for selected projects."),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];

                        final projectName = _getProjectNameById(record.projectId);
                        final vendorName = record.vendorOrSubtrade ?? 'Unknown Vendor';
                        final costAmount = NumberFormat.currency(locale: 'en_US', symbol: '\$').format(record.cost);
                        final itemName = record.itemName ?? 'No Item Description';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.receipt, color: Colors.green),
                            title: Text(
                              '$vendorName | Cost: $costAmount | $itemName',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Project: $projectName | Category: ${record.expenseCategory ?? 'N/A'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                  onPressed: () => _populateFormFromExpense(record),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}