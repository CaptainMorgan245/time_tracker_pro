// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/dashboard_screen.dart'; // For DashboardScreen
import 'package:time_tracker_pro/cost_record_form.dart'; // Form Widget
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/job_materials_repository.dart';
import 'package:time_tracker_pro/settings_service.dart'; // Service for dynamic data
import 'package:time_tracker_pro/models.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/app_bottom_nav_bar.dart'; // NOTE: This import is now redundant but kept for now.

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

  // Repositories and Services
  final _projectRepo = ProjectRepository();
  final _categoryRepo = ExpenseCategoryRepository();
  final _jobMaterialsRepo = JobMaterialsRepository();
  final _settingsService = SettingsService.instance; // Use SettingsService

  // New State Variable for tracking editing mode
  bool _isEditing = false;

  // Data Lists
  List<Project> _allProjects = [];
  List<Project> _filteredProjects = [];
  List<String> _expenseCategories = [];
  List<JobMaterials> _recentExpenses = [];

  // Dynamic Lookup Data from Settings
  List<String> _vendors = [];
  List<String> _vehicleDesignations = [];

  bool _isLoading = true;

  // Default Internal Project
  final Project _internalProject = Project(
    id: 0,
    projectName: 'Internal Company Project',
    clientId: 0,
    isInternal: true,
  );

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  // start method: _loadDependencies
  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryRepo.getExpenseCategories();
      final allProjects = await _projectRepo.getProjects();
      final recentExpenses = await _jobMaterialsRepo.getJobMaterials(limit: 5);
      final settings = await _settingsService.loadSettings();

      // Add the default internal project to the list of all projects
      if (!allProjects.any((p) => p.id == _internalProject.id)) {
        allProjects.insert(0, _internalProject);
      }

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
        _formKey.currentState?.resetForm();
        _loadDependencies();
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

  // start method: _populateFormFromExpense
  void _populateFormFromExpense(JobMaterials expense) {
    _formKey.currentState?.populateForm(expense);
    setState(() {
      _isEditing = true;
    });
    Scrollable.ensureVisible(
      _formKey.currentContext ?? context,
      duration: const Duration(milliseconds: 300),
      alignment: 0.0,
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
  // NOTE: This method is now unused, as CostEntryScreen no longer has a bottom nav bar.
  void _handleBottomNavTap(int index) {
    // Navigates to Dashboard and removes CostEntryScreen from the stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => DashboardScreen(initialIndex: index)),
          (Route<dynamic> route) => false,
    );
  }
  // end method: _handleBottomNavTap

  @override
  Widget build(BuildContext context) {
    // FIX: Wrap the Scaffold in a Material widget with a solid color to block bleed-through from the underlying screen.
    return Material(
      color: Colors.white, // Ensures the background is fully opaque
      child: Scaffold(
        // Ensure no AppBar is present

        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
        // Use SafeArea(bottom: false) to prevent content bleed into the reserved bottom space
            : SafeArea(
          top: false,
          bottom: false, // CRITICAL: Prevents list content from pushing down into nav space
          child: SingleChildScrollView(
            // SingleChildScrollView provides the continuous scroll for the form and the list
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. COST ENTRY FORM
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CostRecordForm(
                      key: _formKey,
                      availableProjects: _filteredProjects,
                      expenseCategories: _expenseCategories,
                      vendors: _vendors,
                      vehicleDesignations: _vehicleDesignations,
                      onAddExpense: _handleCostSubmission,
                      onProjectFilterToggle: _applyProjectFilter,
                      isEditing: _isEditing,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 2. RECENT RECORDS LIST
                const Text(
                  "Recent Expense Records (Tap Edit to Repopulate):",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                _recentExpenses.isEmpty
                    ? const Center(child: Text("No recent expenses found."))
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = _recentExpenses[index];
                    final projectName = _getProjectName(expense.projectId);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(
                          '${expense.itemName} (\$${expense.cost.toStringAsFixed(2)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Project: $projectName | Category: ${expense.expenseCategory ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // NEW: Edit Button (Pencil)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () => _populateFormFromExpense(expense),
                            ),
                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              onPressed: () => _deleteExpense(expense.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // ADD A BUTTON TO CLEAR EDITING STATE
                if (_isEditing)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        _formKey.currentState?.resetForm();
                        setState(() => _isEditing = false);
                      },
                      child: const Text('Cancel Edit / Reset Form', style: TextStyle(color: Colors.blueGrey)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // REMOVED: bottomNavigationBar property entirely.
      ),
    );
  }
}
// end class: _CostEntryScreenState