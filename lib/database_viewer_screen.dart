// lib/database_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/models.dart' as app_models;
import 'package:time_tracker_pro/cost_add_form.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:intl/intl.dart'; // Needed for date formatting

// Ensure JobMaterialsRepository is correctly defined here or imported elsewhere
class JobMaterialsRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final String _tableName = 'materials';

  Future<int> insertJobMaterial(app_models.JobMaterials jobMaterial) async {
    final db = await _databaseHelper.database;
    return await db.insert(_tableName, jobMaterial.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // FIX: Renamed getJobMaterials to getAllJobMaterials for clarity in this viewer
  Future<List<app_models.JobMaterials>> getAllJobMaterials() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName, orderBy: 'id DESC');
    return List.generate(maps.length, (i) {
      return app_models.JobMaterials.fromMap(maps[i]);
    });
  }
}

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  // FIX: Corrected createState to use the full return block structure.
  State<DatabaseViewerScreen> createState() {
    return _DatabaseViewerScreenState();
  }
}

// FIX: Renamed the State class header to the correct private name.
class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  // Renamed MaterialRepository to JobMaterialsRepository
  final JobMaterialsRepository _repo = JobMaterialsRepository();
  final ProjectRepository _projectRepo = ProjectRepository();
  final ExpenseCategoryRepository _categoryRepo = ExpenseCategoryRepository();
  final SettingsService _settingsService = SettingsService.instance;

  // Updated the list to use JobMaterials
  List<app_models.JobMaterials> _expenses = [];
  List<app_models.Project> _projects = [];
  List<String> _expenseCategories = [];
  List<String> _vehicleDesignations = [];
  List<String> _vendors = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // FIX: Call the new getAllJobMaterials method
      final expenses = await _repo.getAllJobMaterials();
      final projects = await _projectRepo.getProjects();
      final categories = await _categoryRepo.getExpenseCategories();
      final settings = await _settingsService.loadSettings();

      setState(() {
        _expenses = expenses;
        _projects = projects;
        _expenseCategories = categories.map((e) => e.name).toList();
        _vehicleDesignations = List<String>.from(settings?.vehicleDesignations ?? []);
        _vendors = List<String>.from(settings?.vendors ?? []);
      });
    } catch (e) {
      debugPrint('Error loading expenses data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to resolve Project Name for display
  String _getProjectName(int projectId) {
    try {
      return _projects.firstWhere((p) => p.id == projectId).projectName;
    } catch (e) {
      return 'ID: $projectId (Missing)';
    }
  }

  // NOTE: This method is a remnant of the old Add Expense functionality, kept for compilation.
  Future<void> _addExpense(app_models.JobMaterials newExpense) async {
    await _repo.insertJobMaterial(newExpense);
    await _loadData();
  }

  // NOTE: This method is a remnant of the old Add Expense FAB functionality, kept for compilation.
  void _showAddExpenseForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ExpenseAddForm(
            projects: _projects,
            expenseCategories: _expenseCategories,
            vehicleDesignations: _vehicleDesignations,
            vendors: _vendors,
            onSubmit: (newExpense) {
              _addExpense(newExpense);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
          ? const Center(child: Text('No expense records found in the database.'))
      // FIX: Updated ListView to display all verification fields
          : ListView.builder(
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          final projectName = _getProjectName(expense.projectId!);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListTile(
              // Display Category and Item Name
              title: Text('${expense.expenseCategory ?? 'N/A'}: ${expense.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),

              // Display verification fields in the subtitle
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Project: $projectName | Vendor: ${expense.vendorOrSubtrade ?? 'None'}'),
                  Text('Date: ${DateFormat('MMM d, yyyy').format(expense.purchaseDate)} | Company: ${expense.isCompanyExpense ? 'Yes' : 'No'}'),
                  if (expense.description != null && expense.description!.isNotEmpty)
                    Text('Notes: ${expense.description}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                ],
              ),

              // Display Cost
              trailing: Text('\$${expense.cost.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            ),
          );
        },
      ),
    );
  }
}