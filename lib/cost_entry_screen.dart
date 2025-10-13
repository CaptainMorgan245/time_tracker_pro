// lib/cost_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart'; // Using V2!
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
  bool _isFormCollapsed = false; // Manages the state for the whole screen

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
    // Collapse if user scrolls down past a certain point
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
        // START FINAL FIX: Add the required 'pricingModel' parameter
        _allProjects.insert(0, Project(id: 0, projectName: 'Internal Company Project', clientId: 0, isInternal: true, pricingModel: 'hourly'));
        // END FINAL FIX
      }

      final formState = _formStateKey.currentState;
      _applyProjectFilter(formState?.showCompletedProjects ?? false);

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load dependency data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyProjectFilter(bool showCompleted) {
    if (showCompleted) {
      _filteredProjectsNotifier.value = _allProjects;
    } else {
      _filteredProjectsNotifier.value = _allProjects.where((p) => !p.isCompleted || p.isInternal).toList();
    }
  }

  void _populateFormFromExpense(JobMaterials expense) {
    _formStateKey.currentState?.populateForm(expense);
    _isCompanyExpenseNotifier.value = expense.isCompanyExpense;
    setState(() {
      _isEditing = true;
      _isFormCollapsed = false; // Ensure form is expanded for editing
    });
    // Animate list to the top if it's scrolled down
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense ${isEditing ? 'updated' : 'added'} successfully.'), duration: const Duration(seconds: 2),),);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting expense: $e')));
      }
    }
  }

  Future<void> _deleteExpense(int id) async {
    try {
      await DatabaseHelperV2.instance.deleteRecordV2(id: id, fromTable: 'materials');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted successfully.'), duration: Duration(seconds: 2),),);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting expense: $e')));
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        top: true,
        bottom: false,
        child: Column( // Using a simple Column layout
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
            Expanded( // The list takes up the remaining space
              child: ValueListenableBuilder<int>(
                valueListenable: dbNotifier,
                builder: (context, _, __) => FutureBuilder<List<JobMaterials>>(
                  future: DatabaseHelperV2.instance.getRecentMaterialsV2(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final recentExpenses = snapshot.data ?? [];
                    if (recentExpenses.isEmpty) {
                      return const Center(child: Text("No recent expenses found."));
                    }
                    return ListView.builder(
                      controller: _scrollController, // Attach controller here
                      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                      itemCount: recentExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = recentExpenses[index];
                        final projectName = _getProjectNameById(expense.projectId);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text('${expense.itemName} (\$${expense.cost.toStringAsFixed(2)})'),
                            subtitle: Text('Project: $projectName | Category: ${expense.expenseCategory ?? 'N/A'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey), onPressed: () => _populateFormFromExpense(expense)),
                                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _deleteExpense(expense.id!)),
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
