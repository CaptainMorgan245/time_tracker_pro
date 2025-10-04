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

  final ValueNotifier<List<Project>> _filteredProjectsNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _expenseCategoriesNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _vendorsNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _vehicleDesignationsNotifier = ValueNotifier([]);

  List<Project> _allProjects = [];

  final Project _internalProject =
  Project(id: 0, projectName: 'Internal Company Project', clientId: 0, isInternal: true);

  @override
  void initState() {
    super.initState();
    _loadAllData();
    dbNotifier.addListener(_loadAllData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    dbNotifier.removeListener(_loadAllData);
    _filteredProjectsNotifier.dispose();
    _expenseCategoriesNotifier.dispose();
    _vendorsNotifier.dispose();
    _vehicleDesignationsNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    debugPrint("[CostEntryScreen] Reloading ALL dropdown data...");

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

      if (!allProjects.any((p) => p.id == _internalProject.id)) {
        allProjects.insert(0, _internalProject);
      }
      _allProjects = allProjects;

      if (!mounted) return;

      _expenseCategoriesNotifier.value = categories.map((c) => c.name).toList();
      _vendorsNotifier.value = List<String>.from(settings.vendors);
      _vehicleDesignationsNotifier.value = List<String>.from(settings.vehicleDesignations);

      // CORRECTED: Read the "show completed" state directly from the form key
      final bool showCompleted = _formStateKey.currentState?.showCompletedProjects ?? false;
      _applyProjectFilter(showCompleted);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load dependency data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyProjectFilter(bool showCompleted) {
    _filteredProjectsNotifier.value = showCompleted
        ? _allProjects
        : _allProjects.where((p) => !p.isCompleted || p.id == _internalProject.id).toList();
  }

  void _populateFormFromExpense(JobMaterials expense) {
    _formStateKey.currentState?.populateForm(expense);
    setState(() => _isEditing = true);
    _scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  // NEW: UNIFIED handler for both clearing the form and canceling an edit
  void _handleClearOrCancel() {
    _formStateKey.currentState?.resetForm();
    if (_isEditing) {
      setState(() => _isEditing = false);
    }
    _scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    try {
      if (isEditing) {
        await DatabaseHelperV2.instance.updateMaterialV2(expense);
      } else {
        await DatabaseHelperV2.instance.addMaterialV2(expense);
      }
      if (mounted) _handleClearOrCancel(); // Calls the new unified handler
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting expense: $e')));
      }
    }
  }

  // CORRECTED: Implemented the delete logic
  Future<void> _deleteExpense(int id) async {
    try {
      await DatabaseHelperV2.instance.deleteRecordV2(id: id, fromTable: 'materials');
      // The dbNotifier will handle reloading the list automatically
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting expense: $e')));
      }
    }
  }

  String _getProjectName(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).projectName;
    } catch (e) {
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
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              delegate: _CostEntryFormSliverDelegate(
                minHeight: 130.0,
                maxHeight: 520.0, // Increased height to prevent overflow
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CostRecordForm(
                    key: _formStateKey,
                    availableProjectsNotifier: _filteredProjectsNotifier,
                    expenseCategoriesNotifier: _expenseCategoriesNotifier,
                    vendorsNotifier: _vendorsNotifier,
                    vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                    onAddExpense: _handleCostSubmission,
                    onProjectFilterToggle: _applyProjectFilter,
                    onClearForm: _handleClearOrCancel, // Pass the new unified handler
                    isEditing: _isEditing,
                  ),
                ),
              ),
              pinned: true,
            ),
            ValueListenableBuilder<int>(
              valueListenable: dbNotifier,
              builder: (context, dbVersion, child) {
                return FutureBuilder<List<JobMaterials>>(
                  future: DatabaseHelperV2.instance.getRecentMaterialsV2(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                          child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator())));
                    }
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                          child: Center(child: Text('Error loading expenses: ${snapshot.error}')));
                    }
                    final recentExpenses = snapshot.data ?? [];
                    if (recentExpenses.isEmpty) {
                      return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 8.0), child: Center(child: Text("No recent expenses found."))),);
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final expense = recentExpenses[index];
                          final projectName = _getProjectName(expense.projectId);
                          final itemNameDisplay = expense.itemName.isNotEmpty ? expense.itemName : '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                title: Text('$itemNameDisplay (\$${expense.cost.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Project: $projectName | Category: ${expense.expenseCategory ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey),onPressed: () => _populateFormFromExpense(expense)),
                                    IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _deleteExpense(expense.id!)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: recentExpenses.length,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// SIMPLIFIED DELEGATE: It is now a "dumb" container for the form.
class _CostEntryFormSliverDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight, maxHeight;
  final Widget child;

  _CostEntryFormSliverDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: -shrinkOffset,
            left: 0,
            right: 0,
            height: maxHeight,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CostEntryFormSliverDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
