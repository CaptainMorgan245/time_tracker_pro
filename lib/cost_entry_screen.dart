// lib/cost_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_model.dart';

// Separate sticky top row widget
class CostRecordFormTopRow extends StatelessWidget {
  final GlobalKey<CostRecordFormState> formStateKey;
  final ValueNotifier<List<Project>> filteredProjectsNotifier;
  final ValueNotifier<List<String>> expenseCategoriesNotifier;
  final ValueNotifier<bool> isCompanyExpenseNotifier;
  final bool showCompletedProjects;
  final Function(bool showCompleted) onProjectFilterToggle;

  const CostRecordFormTopRow({
    super.key,
    required this.formStateKey,
    required this.filteredProjectsNotifier,
    required this.expenseCategoriesNotifier,
    required this.isCompanyExpenseNotifier,
    required this.showCompletedProjects,
    required this.onProjectFilterToggle,
  });

  Project? _getInternalProject() {
    try {
      return filteredProjectsNotifier.value.firstWhere((p) => p.id == 0);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            flex: 4,
            child: ValueListenableBuilder<List<Project>>(
              valueListenable: filteredProjectsNotifier,
              builder: (context, projects, _) {
                final isProjectDropdownEnabled = !isCompanyExpenseNotifier.value;
                final currentProjectSelection = isCompanyExpenseNotifier.value
                    ? _getInternalProject()
                    : formStateKey.currentState?.selectedProject;

                return DropdownButtonFormField<Project>(
                  decoration: InputDecoration(
                    labelText: 'Select Project',
                    suffixIcon: isProjectDropdownEnabled ? const Text('*') : null,
                  ),
                  isDense: true,
                  value: currentProjectSelection,
                  onChanged: isProjectDropdownEnabled
                      ? (Project? newValue) {
                    formStateKey.currentState?.setSelectedProject(newValue!);
                  }
                      : null,
                  items: projects.map((project) {
                    final displayName = project.isInternal
                        ? 'Internal Company Project'
                        : project.projectName;
                    return DropdownMenuItem<Project>(
                      value: project,
                      child: Text(displayName, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 5,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: expenseCategoriesNotifier,
              builder: (context, categories, _) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Expense Category *'),
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
                                formStateKey.currentState?.setSelectedProject(_getInternalProject()!);
                              }
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        },
                      ),
                      const Text(
                        'Company Expense',
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
    if (mounted && _isLoading) setState(() => _isLoading = true);
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

    _formStateKey.currentState?.resetForm();

    if (showCompleted) {
      _filteredProjectsNotifier.value = _allProjects.where((p) => p.isCompleted).toList();
    } else {
      _filteredProjectsNotifier.value = _allProjects.where((p) => !p.isCompleted || p.isInternal).toList();
    }
  }

  void _populateFormFromExpense(JobMaterials expense) {
    _formStateKey.currentState?.populateForm(expense);
    _isCompanyExpenseNotifier.value = expense.isCompanyExpense;
    setState(() {
      _isEditing = true;
      _isFormCollapsed = false; // Always expand form for editing
    });
    // Scroll back to top to see the form
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
    // Auto-focus to bring up keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formStateKey.currentState?.focusFirstField();
    });
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
        _handleClearOrCancel();
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // STICKY TOP ROW - never scrolls away but looks integrated
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
                isCompanyExpenseNotifier: _isCompanyExpenseNotifier,
                showCompletedProjects: _showCompletedProjects,
                onProjectFilterToggle: _applyProjectFilter,
              ),
            ),

            // COLLAPSIBLE FORM BODY - integrates visually with top row
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
                  isCollapsed: false, // Always show body when visible
                  onCollapseToggle: () {}, // Not used
                ),
              ),
            ),

            const Divider(height: 1),

            // SCROLLABLE EXPENSE LIST
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: dbNotifier,
                builder: (context, _, __) => FutureBuilder<List<dynamic>>(
                  key: ValueKey(_showCompletedProjects),
                  future: DatabaseHelperV2.instance.getProjectRecordsV2(
                    _showCompletedProjects,
                    _allProjects,
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
                          child: Text("No records found for selected projects."),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];

                        if (record is JobMaterials) {
                          final projectName = _getProjectNameById(record.projectId);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.receipt, color: Colors.green),
                              title: Text(
                                'EXPENSE: ${record.itemName} (\$${record.cost.toStringAsFixed(2)})',
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
                        }
                        return const SizedBox.shrink();
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
/*
  Project? _getInternalProject() {
    try {
      return _allProjects.firstWhere((p) => p.id == 0);
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }
  */
}