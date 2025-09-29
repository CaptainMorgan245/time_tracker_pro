// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/job_materials_repository.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:intl/intl.dart';
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

  // Repositories and Services
  final _projectRepo = ProjectRepository();
  final _categoryRepo = ExpenseCategoryRepository();
  final _jobMaterialsRepo = JobMaterialsRepository();
  final _settingsService = SettingsService.instance;

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
      final recentExpenses = await _jobMaterialsRepo.getAllJobMaterials();
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
    // Scroll to the top of the form after repopulating
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
  void _handleBottomNavTap(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => DashboardScreen(initialIndex: index)),
          (Route<dynamic> route) => false,
    );
  }
  // end method: _handleBottomNavTap

  @override
  Widget build(BuildContext context) {
    // FIX: Using LayoutBuilder to determine available screen height
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The height of the form and header elements (estimated or measured)
            // Assuming the form is roughly 500 pixels high, plus margins/text
            // This is the tricky part that often needs calibration.
            const double formHeightEstimate = 550.0;
            const double listHeaderHeight = 50.0;
            const double totalFixedContentHeight = formHeightEstimate + listHeaderHeight;

            // Calculate the remaining height for the scrollable list
            final double remainingHeight = constraints.maxHeight - totalFixedContentHeight;

            // The scrollable list needs a minimum height if there is no data
            final double listHeight = remainingHeight > 0 ? remainingHeight : 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. STICKY FORM (Always visible, wrapped in a SingleChildScrollView for internal form scrolling if needed)
                SingleChildScrollView(
                  // Restrict the height of the form area
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 32.0),
                        child: Card(
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
                      ),
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

                // 3. INDEPENDENTLY SCROLLABLE RECORDS LIST (Constrained by height)
                Expanded(
                  child: _recentExpenses.isEmpty
                      ? const Center(child: Text("No recent expenses found."))
                      : ListView.builder(
                    // List itself handles its own scrolling
                    itemCount: _recentExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = _recentExpenses[index];
                      final projectName = _getProjectName(expense.projectId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Card(
                          margin: EdgeInsets.zero,
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
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
// end class: _CostEntryScreenState