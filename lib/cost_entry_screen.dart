// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/job_materials_repository.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/app_bottom_nav_bar.dart';

// start class: CostEntryScreen
class CostEntryScreen extends StatefulWidget {
  const CostEntryScreen({super.key});

  @override
  State<CostEntryScreen> createState() => _CostEntryScreenState();
}
// end class: CostEntryScreen

// start class: _CostEntryScreenState
class _CostEntryScreenState extends State<CostEntryScreen> {
  // GlobalKey used to access and validate the form data
  final _formKey = GlobalKey<CostRecordFormState>();
  final _scrollController = ScrollController();

  // Repositories and Services
  final _projectRepo = ProjectRepository();
  final _categoryRepo = ExpenseCategoryRepository();
  final _jobMaterialsRepo = JobMaterialsRepository();
  final _settingsService = SettingsService.instance;

  // State Variables
  bool _isEditing = false;
  bool _isLoading = true;

  // Data Lists
  List<Project> _allProjects = [];
  List<Project> _filteredProjects = [];
  List<String> _expenseCategories = [];
  List<JobMaterials> _recentExpenses = [];

  // Dynamic Lookup Data from Settings
  List<String> _vendors = [];
  List<String> _vehicleDesignations = [];

  // Default Internal Project
  final Project _internalProject = Project(
    id: 0,
    projectName: 'Internal Company Project',
    clientId: 0,
    isInternal: true,
  );

  // *********************************************************
  // FINAL FIX: Using WidgetsBinding.instance.addPostFrameCallback
  // This is the guaranteed way to force a state reload after navigation.
  // *********************************************************
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the form is rebuilt with the latest data
    // right after the initial render cycle (or navigation return).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDependencies();
    });
  }

  // NOTE: didChangeDependencies() and the Observer pattern are removed.

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // start method: _loadDependencies
  Future<void> _loadDependencies() async {
    // Only show loading indicator if this is the very first load
    if (_allProjects.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final categories = await _categoryRepo.getExpenseCategories();
      final allProjects = await _projectRepo.getProjects();

      final recentExpenses = await _jobMaterialsRepo.getAllJobMaterials();
      final settings = await _settingsService.loadSettings();

      // Add the default internal project to the list of all projects
      if (!allProjects.any((p) => p.id == _internalProject.id)) {
        allProjects.insert(0, _internalProject);
      }

      if (!mounted) return;

      setState(() {
        _allProjects = allProjects;
        _expenseCategories = categories.map((c) => c.name).toList();
        _recentExpenses = recentExpenses;

        // Load dynamic data from settings
        _vendors = List<String>.from(settings?.vendors ?? []);
        _vehicleDesignations = List<String>.from(settings?.vehicleDesignations ?? []);

        _applyProjectFilter(false);
        _isLoading = false;
        _isEditing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dependency data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  // end method: _loadDependencies

  // start method: _applyProjectFilter
  void _applyProjectFilter(bool showCompleted) {
    if (showCompleted) {
      _filteredProjects = _allProjects;
    } else {
      _filteredProjects = _allProjects.where((p) => !p.isCompleted || p.id == _internalProject.id).toList();
    }
    setState(() {});
    _formKey.currentState?.forceRebuild();
  }
  // end method: _applyProjectFilter

  // start method: _handleCostSubmission
  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    try {
      if (isEditing) {
        await _jobMaterialsRepo.updateJobMaterial(expense);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated successfully!')),
        );
      } else {
        await _jobMaterialsRepo.insertJobMaterial(expense);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense recorded successfully!')),
        );
      }

      if (mounted) {
        _handleCancelEdit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save expense: $e')),
        );
      }
    }
  }
  // end method: _handleCostSubmission

  // Handles cancelling edit mode and resetting form/data
  void _handleCancelEdit() {
    _formKey.currentState?.resetForm();
    setState(() => _isEditing = false);
    _loadDependencies(); // Reloads the list to show the new entry
    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  // start method: _populateFormFromExpense
  void _populateFormFromExpense(JobMaterials expense) {
    _formKey.currentState?.populateForm(expense);
    setState(() {
      _isEditing = true;
    });
    // Scroll to the top of the CustomScrollView after repopulating
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
  // end method: _populateFormFromExpense

  // start method: _deleteExpense
  Future<void> _deleteExpense(int id) async {
    try {
      await _jobMaterialsRepo.deleteJobMaterial(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted.')),
      );
      _loadDependencies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete expense: $e')),
      );
    }
  }
  // end method: _deleteExpense

  // start method: _getProjectName
  String _getProjectName(int projectId) {
    try {
      final project = _allProjects.firstWhere((p) => p.id == projectId);
      return project.projectName;
    } catch (e) {
      return 'Unknown Project';
    }
  }
  // end method: _getProjectName

  // start method: _handleBottomNavTap
  void _handleBottomNavTap(int index) {
    // Only navigate if the index is NOT for the current screen (0 for CostEntryScreen)
    if (index != 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => DashboardScreen(initialIndex: index)),
            (Route<dynamic> route) => false,
      );
    }
  }
  // end method: _handleBottomNavTap

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
            // 1. COLLAPSIBLE/PINNED FORM HEADER
            SliverPersistentHeader(
              delegate: _CostEntryFormSliverDelegate(
                minHeight: 130.0,
                maxHeight: 450.0,
                formWidget: CostRecordForm(
                  key: _formKey,
                  availableProjects: _filteredProjects,
                  expenseCategories: _expenseCategories,
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

            // 2. RECENT RECORDS LIST
            _recentExpenses.isEmpty
                ? const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Center(child: Text("No recent expenses found.")),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final expense = _recentExpenses[index];
                  final projectName = _getProjectName(expense.projectId);

                  // FIX: Display empty string for null/empty item names instead of "N/A"
                  final itemNameDisplay = expense.itemName != null && expense.itemName!.isNotEmpty
                      ? expense.itemName!
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(
                          '$itemNameDisplay (\$${expense.cost.toStringAsFixed(2)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Project: $projectName | Category: ${expense.expenseCategory ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () => _populateFormFromExpense(expense),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              onPressed: () => _deleteExpense(expense.id!),
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
// end class: _CostEntryScreenState


// start class: _CostEntryFormSliverDelegate
class _CostEntryFormSliverDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
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

    // Calculates the fraction of the header that is currently covered by the scroll
    final double scrollProgress =
    (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);

    // Determines the opacity of the Cancel Edit button
    final double buttonOpacity = 1.0 - scrollProgress;

    // Use a Stack and Positioned to correctly clip the content.
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Positioned widget handles the vertical translation (the collapsing effect).
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
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
                        child: formWidget,
                      ),
                      // 2. The Cancel Edit/Clear Form Button
                      if (isEditing)
                        Opacity(
                          opacity: buttonOpacity.clamp(0.0, 1.0),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: TextButton(
                              onPressed: onCancelEdit,
                              child: const Text('Cancel Edit / Clear Form',
                                  style: TextStyle(color: Colors.blueGrey)),
                            ),
                          ),
                        ),
                      // Add minimal spacing to ensure the list doesn't hug the form too tightly
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
// end class: _CostEntryFormSliverDelegate