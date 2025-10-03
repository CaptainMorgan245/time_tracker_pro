// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart'; // Using V2!
//import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';

class CostEntryScreen extends StatefulWidget {
  const CostEntryScreen({super.key});

  @override
  State<CostEntryScreen> createState() => _CostEntryScreenState();
}

class _CostEntryScreenState extends State<CostEntryScreen> {
  final _formKey = GlobalKey<CostRecordFormState>();
  final _scrollController = ScrollController();

  // Repositories for data that is not yet reactive
  final _projectRepo = ProjectRepository();
  final _settingsService = SettingsService.instance;

  // V2: We need access to the notifier for reactive updates
  final dbNotifier = DatabaseHelperV2.instance.databaseNotifier;

  bool _isEditing = false;
  bool _isLoading = true;

  // State for dropdowns
  List<Project> _allProjects = [];
  List<Project> _filteredProjects = [];
  List<String> _expenseCategories = [];
  List<String> _vendors = [];
  List<String> _vehicleDesignations = [];
  // NOTE: _recentExpenses is now fully managed by a ValueListenableBuilder

  final Project _internalProject =
  Project(id: 0, projectName: 'Internal Company Project', clientId: 0, isInternal: true);

  @override
  void initState() {
    super.initState();
    // Load data that doesn't need to be reactive
    _loadNonReactiveData();
    // Listen for database changes to reload dropdowns
    dbNotifier.addListener(_reloadDropdownData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Always remove the listener
    dbNotifier.removeListener(_reloadDropdownData);
    super.dispose();
  }

  /// This method is called reactively when the database changes.
  /// It specifically re-fetches data for dropdown menus.
  Future<void> _reloadDropdownData() async {
    debugPrint("[CostEntryScreen] Notified of DB change. Reloading dropdown data...");
    // Fetch the latest categories using the V2 helper
    final cats = await DatabaseHelperV2.instance.getExpenseCategoriesV2();
    // We could add vendors/vehicles here in the future

    if (!mounted) return;

    // Call setState to trigger a UI rebuild for the dropdowns.
    setState(() {
      _expenseCategories = cats.map((c) => c.name).toList();
    });
  }

  /// Loads data that does not change often ONCE on startup.
  Future<void> _loadNonReactiveData() async {
    setState(() => _isLoading = true);

    try {
      // Use V2 for categories from the start
      final categories = await DatabaseHelperV2.instance.getExpenseCategoriesV2();
      // Load other non-reactive data
      final allProjects = await _projectRepo.getProjects();
      final settings = await _settingsService.loadSettings();

      if (!allProjects.any((p) => p.id == _internalProject.id)) {
        allProjects.insert(0, _internalProject);
      }

      if (!mounted) return;

      setState(() {
        _allProjects = allProjects;
        _expenseCategories = categories.map((c) => c.name).toList();
        // FIX #1: Removed unnecessary null-aware operators `?.`
        _vendors = List<String>.from(settings.vendors);
        _vehicleDesignations = List<String>.from(settings.vehicleDesignations);

        _applyProjectFilter(false);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load initial dependency data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyProjectFilter(bool showCompleted) {
    _filteredProjects = showCompleted
        ? _allProjects
        : _allProjects.where((p) => !p.isCompleted || p.id == _internalProject.id).toList();
    setState(() {});
    _formKey.currentState?.forceRebuild();
  }

  /// V2: Handles submission by calling the V2 helper. The UI updates automatically.
  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    try {
      if (isEditing) {
        await DatabaseHelperV2.instance.updateMaterialV2(expense);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Expense updated successfully!')));
        }
      } else {
        await DatabaseHelperV2.instance.addMaterialV2(expense);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Expense recorded successfully!')));
        }
      }
      if (mounted) _handleCancelEdit();
      // NO manual refresh needed. The ValueListenableBuilder handles it.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
      }
    }
  }

  /// V2: Deletes an expense by calling the V2 helper.
  Future<void> _deleteExpense(int id) async {
    try {
      await DatabaseHelperV2.instance.deleteRecordV2(id: id, fromTable: 'materials');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense deleted.')));
      }
      // NO manual refresh needed.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
      }
    }
  }

  void _handleCancelEdit() {
    _formKey.currentState?.resetForm();
    setState(() => _isEditing = false);
    _scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _populateFormFromExpense(JobMaterials expense) {
    _formKey.currentState?.populateForm(expense);
    setState(() => _isEditing = true);
    _scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  String _getProjectName(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).projectName;
    } catch (e) {
      return 'Unknown Project';
    }
  }

  // FIX #2: The unused _handleBottomNavTap method has been completely removed.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                maxHeight: 450.0,
                formWidget: CostRecordForm(
                  key: _formKey,
                  availableProjects: _filteredProjects,
                  expenseCategories: _expenseCategories, // This list is reactive
                  vendors: _vendors,
                  vehicleDesignations: _vehicleDesignations,
                  onAddExpense: _handleCostSubmission,
                  onProjectFilterToggle: _applyProjectFilter,
                  isEditing: _isEditing,
                ),
                isEditing: _isEditing,
                onCancelEdit: _handleCancelEdit,
              ),
              pinned: true,
            ),
            // THIS IS THE FULLY REACTIVE LIST OF RECENT EXPENSES
            ValueListenableBuilder<int>(
              valueListenable: dbNotifier,
              builder: (context, dbVersion, child) {
                debugPrint("[CostEntryScreen] Rebuilding recent expenses list due to DB version $dbVersion");
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
                      return const SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Center(child: Text("No recent expenses found."))),
                      );
                    }
                    // If we have data, we build the SliverList.
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final expense = recentExpenses[index];
                          final projectName =
                          _getProjectName(expense.projectId);

                          // FIX #3: Simplified the logic since expense.itemName cannot be null.
                          final itemNameDisplay = expense.itemName.isNotEmpty
                              ? expense.itemName
                              : '';

                          return Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                title: Text(
                                    '$itemNameDisplay (\$${expense.cost.toStringAsFixed(2)})',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Project: $projectName | Category: ${expense.expenseCategory ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                        onPressed: () => _populateFormFromExpense(expense)),
                                    IconButton(
                                        icon: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.red),
                                        onPressed: () => _deleteExpense(expense.id!)),
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

// Unchanged Sliver Header Delegate
class _CostEntryFormSliverDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight, maxHeight;
  final Widget formWidget;
  final bool isEditing;
  final VoidCallback onCancelEdit;

  _CostEntryFormSliverDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.formWidget,
    required this.isEditing,
    required this.onCancelEdit,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double scrollProgress =
    (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);
    final double buttonOpacity = 1.0 - scrollProgress;

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
                        child: formWidget,
                      ),
                      if (isEditing)
                        Opacity(
                          opacity: buttonOpacity.clamp(0.0, 1.0),
                          child: Padding(
                            padding:
                            const EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: TextButton(
                              onPressed: onCancelEdit,
                              child: const Text('Cancel Edit / Clear Form',
                                  style: TextStyle(color: Colors.blueGrey)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
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
        isEditing != oldDelegate.isEditing;
  }
}
