// lib/cost_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_model.dart';

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
      _isFormCollapsed = false;
    });
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
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
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: Column(
              children: [
                Card(
                  elevation: 2.0,
                  margin: const EdgeInsets.all(8),
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
                    onCompanyExpenseToggle: (isCompanyExpense) {
                      _isCompanyExpenseNotifier.value = isCompanyExpense;
                    },
                    isCollapsed: _isFormCollapsed,
                    onCollapseToggle: () {
                      setState(() {
                        _isFormCollapsed = !_isFormCollapsed;
                      });
                    },
                  ),
                ),
                const Divider(height: 1),
                ValueListenableBuilder<int>(
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
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];

                          if (record is TimeEntry) {
                            final projectName = _getProjectNameById(record.projectId);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: Colors.blue.shade50,
                              child: ListTile(
                                leading: const Icon(Icons.access_time, color: Colors.blue),
                                title: Text('TIME: $projectName'),
                                subtitle: Text(
                                  '${record.startTime.toString().split(' ')[0]} - ${_formatDuration((record.finalBilledDurationSeconds ?? 0).toInt())}',
                                ),
                                trailing: const Text(
                                  'Tap to add expense',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                onTap: () {
                                  final project = _allProjects.firstWhere((p) => p.id == record.projectId);
                                  _formStateKey.currentState?.resetForm();
                                  _formStateKey.currentState?.setSelectedProject(project);
                                  setState(() {
                                    _isEditing = false;
                                    _isFormCollapsed = false;
                                  });
                                  if (_scrollController.hasClients && _scrollController.offset > 0) {
                                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                                  }
                                },
                              ),
                            );
                          } else if (record is JobMaterials) {
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }
}