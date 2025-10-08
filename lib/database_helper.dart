// lib/database_helper.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
// We do NOT import path.dart or dart:io because we are letting the plugin handle the path.
import 'package:time_tracker_pro/models.dart';

// ============================================================================
// |                         ACTIVE V2 DATABASE HELPER                        |
// ============================================================================

class DatabaseHelperV2 {
  DatabaseHelperV2._privateConstructor();
  static final DatabaseHelperV2 instance = DatabaseHelperV2._privateConstructor();

  static Database? _database;
  static const String _dbName = 'time_tracker_pro.db';
  static const int _dbVersion = 1;

  final ValueNotifier<int> databaseNotifier = ValueNotifier(0);

  void _notifyListeners() {
    databaseNotifier.value++;
    debugPrint('[DB_V2] Database change notified. Version: ${databaseNotifier.value}');
  }

  void notifyDatabaseChanged() {
    _notifyListeners();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ================================================================================
  // THIS IS THE FINAL, CORRECTED LOGIC.
  // It specifies NO PATH, forcing sqflite to use its correct default location.
  // ================================================================================
  Future<Database> _initDatabase() async {
    // By providing only the name, we let the sqflite_common_ffi plugin manage
    // the path automatically, which correctly places it in the .dart_tool folder.
    debugPrint("[DB_V2_DEFAULT_PATH] Initializing database with default path logic...");
    return await openDatabase(
      _dbName, // Just the name, no path.
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  // This _onCreate method is still correct and will ONLY RUN IF THE DB FILE DOES NOT EXIST.
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB_V2] ERROR: _onCreate was called but DB should exist. Creating tables anyway...');
    await db.transaction((txn) async {
      // All the CREATE TABLE statements are here, unchanged.
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY, employee_number_prefix TEXT, next_employee_number INTEGER, vehicle_designations TEXT, vendors TEXT, company_hourly_rate REAL, burden_rate REAL, time_rounding_interval INTEGER, auto_backup_reminder_frequency INTEGER, app_runs_since_backup INTEGER, measurement_system TEXT, default_report_months INTEGER
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, contact_person TEXT, phone_number TEXT
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_name TEXT NOT NULL, client_id INTEGER NOT NULL, location TEXT, pricing_model TEXT DEFAULT 'hourly', is_completed INTEGER NOT NULL DEFAULT 0, completion_date TEXT, is_internal INTEGER NOT NULL DEFAULT 0, billed_hourly_rate REAL, FOREIGN KEY (client_id) REFERENCES clients(id), UNIQUE(project_name, client_id)
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, standard_rate REAL NOT NULL DEFAULT 0.0
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT, employee_number TEXT UNIQUE, name TEXT NOT NULL, title_id INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (title_id) REFERENCES roles(id)
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS time_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER, employee_id INTEGER, start_time TEXT NOT NULL, end_time TEXT, paused_duration REAL DEFAULT 0.0, final_billed_duration_seconds REAL, is_paused INTEGER DEFAULT 0, pause_start_time TEXT, is_deleted INTEGER DEFAULT 0, work_details TEXT, FOREIGN KEY (project_id) REFERENCES projects(id), FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS materials (
            id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER, item_name TEXT NOT NULL, cost REAL NOT NULL, purchase_date TEXT, description TEXT, is_deleted INTEGER DEFAULT 0, expense_category TEXT, unit TEXT, quantity REAL, base_quantity REAL, odometer_reading REAL, is_company_expense INTEGER DEFAULT 0, vehicle_designation TEXT, vendor_or_subtrade TEXT, FOREIGN KEY (project_id) REFERENCES projects(id)
          )
        ''');
      await txn.execute('''
          CREATE TABLE IF NOT EXISTS expense_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL
          )
        ''');
    });
    debugPrint('[DB_V2] All tables created successfully.');
  }

  // --- V2 PUBLIC METHODS --- (Unchanged)
  Future<List<AllRecordViewModel>> getAllRecordsV2() async {
    // ... same as before
    final db = await database;
    final List<AllRecordViewModel> allRecords = [];
    final timeQuery = '''
      SELECT t.id, t.start_time, t.work_details, t.final_billed_duration_seconds, p.project_name, c.name as client_name
      FROM time_entries t
      JOIN projects p ON t.project_id = p.id
      JOIN clients c ON p.client_id = c.id
      WHERE t.is_deleted = 0 AND t.start_time IS NOT NULL
    ''';
    final timeEntryMaps = await db.rawQuery(timeQuery);
    for (var map in timeEntryMaps) {
      final projectName = map['project_name'] as String? ?? 'Unknown Project';
      final clientName = map['client_name'] as String? ?? 'Unknown Client';
      allRecords.add(AllRecordViewModel(id: map['id'] as int, type: RecordType.time, date: DateTime.parse(map['start_time'] as String), description: map['work_details'] as String? ?? 'No Details', value: (map['final_billed_duration_seconds'] as num? ?? 0.0) / 3600.0, categoryOrProject: '$clientName - $projectName',));
    }
    final materialQuery = '''
      SELECT m.id, m.purchase_date, m.item_name, m.cost, m.expense_category, p.project_name
      FROM materials m
      JOIN projects p ON m.project_id = p.id
      WHERE m.is_deleted = 0 AND m.purchase_date IS NOT NULL
    ''';
    final materialMaps = await db.rawQuery(materialQuery);
    for (var map in materialMaps) {
      final category = map['expense_category'] as String?;
      final projectName = map['project_name'] as String?;
      String displayCategory = category ?? projectName ?? 'Uncategorized';
      allRecords.add(AllRecordViewModel(id: map['id'] as int, type: RecordType.expense, date: DateTime.parse(map['purchase_date'] as String), description: map['item_name'] as String? ?? 'Unnamed Item', value: (map['cost'] as num? ?? 0.0).toDouble(), categoryOrProject: displayCategory,));
    }
    allRecords.sort((a, b) => b.id.compareTo(a.id));
    return allRecords;
  }
  Future<List<ExpenseCategory>> getExpenseCategoriesV2() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expense_categories', orderBy: 'name');
    return List.generate(maps.length, (i) => ExpenseCategory.fromMap(maps[i]));
  }
  Future<List<JobMaterials>> getRecentMaterialsV2() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('materials', where: 'is_deleted = 0', orderBy: 'purchase_date DESC', limit: 100,);
    return List.generate(maps.length, (i) => JobMaterials.fromMap(maps[i]));
  }
  Future<void> addMaterialV2(JobMaterials expense) async {
    final db = await database;
    await db.insert('materials', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyListeners();
  }
  Future<void> updateMaterialV2(JobMaterials expense) async {
    final db = await database;
    await db.update('materials', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
    _notifyListeners();
  }
  Future<void> addExpenseCategoryV2(ExpenseCategory category) async {
    final db = await database;
    await db.insert('expense_categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyListeners();
  }
  Future<void> updateExpenseCategoryV2(ExpenseCategory category) async {
    final db = await database;
    await db.update('expense_categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
    _notifyListeners();
  }
  Future<void> deleteRecordV2({required int id, required String fromTable}) async {
    final db = await database;
    if (fromTable == 'time_entries' || fromTable == 'materials') {
      await db.update(fromTable, {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.delete(fromTable, where: 'id = ?', whereArgs: [id]);
    }
    _notifyListeners();
  }
}
