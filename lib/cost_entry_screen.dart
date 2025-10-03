// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart'; // Using V2!
import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
// V2 CHANGE: Old category repo is no longer needed for reactive updates
// import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/job_materials_repository.dart';
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

  // Keep old repos for things we haven't made reactive yet
  final _jobMaterialsRepo = JobMaterialsRepository();
  final _projectRepo = ProjectRepository();
  // final _categoryRepo = ExpenseCategoryRepository(); // V2 CHANGE: Removed
  final _settingsService = SettingsService.instance;

  // V2 CHANGE: We need access to the notifier
  final dbNotifier = DatabaseHelperV2.instance.databaseNotifier;

  bool _isEditing = false;
  bool _isLoading = true;

  // State for dropdowns and lists
  List<Project> _allProjects = [];
  List<Project> _filteredProjects = [];
  List<String> _expenseCategories = []; // This will now be updated reactively
  List<JobMaterials> _recentExpenses = [];
  List<String> _vendors = [];
  List<String> _vehicleDesignations = [];

  final Project _internalProject =
  Project(id: 0, projectName: 'Internal Company Project', clientId: 0, isInternal: true);

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Load everything once at the start
    // V2 CHANGE: Listen for database changes to reload dropdowns
    dbNotifier.addListener(_reloadDropdownData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // V2 CHANGE: Always remove the listener
    dbNotifier.removeListener(_reloadDropdownData);
    super.dispose();
  }

  /// V2 CHANGE: This method is called reactively when the database changes.
  /// It specifically re-fetches data for dropdown menus.
  Future<void> _reloadDropdownData() async {
    debugPrint("[CostEntryScreen] Notified of DB change. Reloading dropdown data...");
    // Fetch the latest categories using the V2 helper
    final cats = await DatabaseHelperV2.instance.getExpenseCategoriesV2();

    // We can add vendors and vehicles here later if they become reactive

    if (!mounted) return;

    setState(() {
      _expenseCategories = cats.map((c) => c.name).toList();
    });
  }

  /// Loads all data when the screen is first created.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Use V2 for categories from the start
      final categories = await DatabaseHelperV2.instance.getExpenseCategoriesV2();
      // Other dependencies are loaded the old way for now
      final allProjects = await _projectRepo.getProjects();
      final settings = await _settingsService.loadSettings();
      final recentExpenses = await _jobMaterialsRepo.getAllJobMaterials();

      if (!allProjects.any((p) => p.id == _internalProject.id)) {
        allProjects.insert(0, _internalProject);
      }

      if (!mounted) return;

      setState(() {
        _allProjects = allProjects;
        _expenseCategories = categories.map((c) => c.name).toList();
        _vendors = List<String>.from(settings?.vendors ?? []);
        _vehicleDesignations = List<String>.from(settings?.vehicleDesignations ?? []);
        _recentExpenses = recentExpenses;

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

  // Reloads both recent expenses and dropdowns (legacy behavior for now)
  Future<void> _reloadData() async {
    await _loadInitialData();
  }

  void _applyProjectFilter(bool showCompleted) {
    _filteredProjects = showCompleted
        ? _allProjects
        : _allProjects.where((p) => !p.isCompleted || p.id == _internalProject.id).toList();
    setState(() {});
    _formKey.currentState?.forceRebuild();
  }

  // This uses the OLD repository. We fixed this once, but reverted.
  // We can re-fix this in the next step if we want.
  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    try {
      if (isEditing) {
        await _jobMaterialsRepo.updateJobMaterial(expense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expense updated successfully!')));
        }
      } else {
        await _jobMaterialsRepo.insertJobMaterial(expense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expense recorded successfully!')));
        }
      }
      _reloadData(); // Manual refresh of recent expenses list
      _handleCancelEdit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
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

  Future<void> _deleteExpense(int id) async {
    try {
      await _jobMaterialsRepo.deleteJobMaterial(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense deleted.')));
      }
      _reloadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
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

  void _handleBottomNavTap(int index) {
    // This is the original navigation logic from before
    final route = ModalRoute.of(context);
    if (route is PageRoute && route.isFirst) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(initialIndex: index),
        ),
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(initialIndex: index),
        ),
            (Route<dynamic> route) => false,
      );
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
                  expenseCategories: _expenseCategories, // This list is now reactive
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
            _recentExpenses.isEmpty
                ? const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Center(
                    child: Text("No recent expenses found.")),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final expense = _recentExpenses[index];
                  final projectName =
                  _getProjectName(expense.projectId);
                  final itemNameDisplay =
                  expense.itemName != null &&
                      expense.itemName!.isNotEmpty
                      ? expense.itemName!
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(
                          '$itemNameDisplay (\$${expense.cost.toStringAsFixed(2)})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Project: $projectName | Category: ${expense.expenseCategory ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueGrey),
                              onPressed: () =>
                                  _populateFormFromExpense(
                                      expense),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.red),
                              onPressed: () =>
                                  _deleteExpense(expense.id!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _recentExpenses.length,
              ),
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
