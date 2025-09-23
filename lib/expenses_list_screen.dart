// lib/expenses_list_screen.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/models.dart' as app_models;
import 'package:time_tracker_pro/expense_add_form.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';

// The MaterialRepository has been renamed to JobMaterialsRepository
class JobMaterialsRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insertJobMaterial(app_models.JobMaterials jobMaterial) async {
    final db = await _databaseHelper.database;
    return await db.insert('materials', jobMaterial.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<app_models.JobMaterials>> getJobMaterials() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('materials');
    return List.generate(maps.length, (i) {
      return app_models.JobMaterials.fromMap(maps[i]);
    });
  }
}

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
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
      // Updated getMaterials to getJobMaterials
      final expenses = await _repo.getJobMaterials();
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

  // Updated the parameter type to JobMaterials
  Future<void> _addExpense(app_models.JobMaterials newExpense) async {
    await _repo.insertJobMaterial(newExpense);
    await _loadData();
  }

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
        title: const Text('Expenses'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
          ? const Center(child: Text('No expenses recorded.'))
          : ListView.builder(
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          return ListTile(
            title: Text(expense.itemName),
            subtitle: Text(expense.description ?? ''),
            trailing: Text('\$${expense.cost.toStringAsFixed(2)}'),
            onTap: () {
              // TODO: Implement edit functionality
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}