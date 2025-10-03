// lib/database_helper.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker_pro/models.dart';

// ============================================================================
// |                         NEW REFACTORED CODE                              |
// ============================================================================

class DatabaseHelperV2 {
  DatabaseHelperV2._privateConstructor();
  static final DatabaseHelperV2 instance = DatabaseHelperV2._privateConstructor();

  // V2 shares the single database instance with the legacy helper
  static Database? get _database => DatabaseHelper._database;
  static set _database(Database? db) => DatabaseHelper._database = db;

  // The notifier that will drive all our reactive UI updates.
  final ValueNotifier<int> databaseNotifier = ValueNotifier(0);

  void _notifyListeners() {
    databaseNotifier.value++;
    debugPrint('[DB_V2] Database change notified. Version: ${databaseNotifier.value}');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // V2 initialization defers to the legacy _onCreate to ensure tables are only created once.
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'time_tracker_pro.db');
    return await openDatabase(path, version: 1, onCreate: DatabaseHelper.instance._onCreate);
  }

  // --- V2 PUBLIC METHODS ---

  Future<List<AllRecordViewModel>> getAllRecordsV2() async {
    final db = await database;
    final List<AllRecordViewModel> allRecords = [];

    // --- TIME ENTRIES QUERY ---
    final timeQuery = '''
      SELECT
        t.id, t.start_time, t.work_details, t.final_billed_duration_seconds,
        p.project_name, c.name as client_name
      FROM time_entries t
      JOIN projects p ON t.project_id = p.id
      JOIN clients c ON p.client_id = c.id
      WHERE t.is_deleted = 0 AND t.start_time IS NOT NULL
    ''';
    final timeEntryMaps = await db.rawQuery(timeQuery);

    for (var map in timeEntryMaps) {
      final projectName = map['project_name'] as String? ?? 'Unknown Project';
      final clientName = map['client_name'] as String? ?? 'Unknown Client';
      allRecords.add(AllRecordViewModel(
        id: map['id'] as int,
        type: RecordType.time,
        date: DateTime.parse(map['start_time'] as String),
        description: map['work_details'] as String? ?? 'No Details',
        value: (map['final_billed_duration_seconds'] as num? ?? 0.0) / 3600.0, // hours
        categoryOrProject: '$clientName - $projectName',
      ));
    }

    // --- MATERIALS (EXPENSE) QUERY ---
    final materialQuery = '''
      SELECT
        m.id, m.purchase_date, m.item_name, m.cost, m.expense_category,
        p.project_name
      FROM materials m
      JOIN projects p ON m.project_id = p.id
      WHERE m.is_deleted = 0 AND m.purchase_date IS NOT NULL
    ''';
    final materialMaps = await db.rawQuery(materialQuery);

    for (var map in materialMaps) {
      final category = map['expense_category'] as String?;
      final projectName = map['project_name'] as String?;
      String displayCategory = category ?? projectName ?? 'Uncategorized';

      allRecords.add(AllRecordViewModel(
        id: map['id'] as int,
        type: RecordType.expense,
        date: DateTime.parse(map['purchase_date'] as String),
        description: map['item_name'] as String? ?? 'Unnamed Item',
        value: (map['cost'] as num? ?? 0.0).toDouble(),
        categoryOrProject: displayCategory,
      ));
    }

    allRecords.sort((a, b) => b.date.compareTo(a.date));
    return allRecords;
  }

  /// Fetches the list of all expense categories.
  Future<List<ExpenseCategory>> getExpenseCategoriesV2() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expense_categories', orderBy: 'name');

    List<ExpenseCategory> categories = List.generate(maps.length, (i) {
      return ExpenseCategory.fromMap(maps[i]);
    });

    debugPrint('[DB_V2] getExpenseCategoriesV2 found ${categories.length} categories.');
    return categories;
  }

  /// Fetches recent JobMaterials records, ordered by date.
  Future<List<JobMaterials>> getRecentMaterialsV2() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'materials',
      where: 'is_deleted = 0',
      orderBy: 'purchase_date DESC',
      limit: 100, // Limit to a reasonable number for display
    );
    final results = List.generate(maps.length, (i) => JobMaterials.fromMap(maps[i]));
    debugPrint('[DB_V2] getRecentMaterialsV2 found ${results.length} records.');
    return results;
  }

  // --- V2 CRUD FOR MATERIALS (EXPENSES) ---

  /// Adds a new material/expense from a JobMaterials model and notifies listeners.
  Future<void> addMaterialV2(JobMaterials expense) async {
    final db = await database;
    try {
      await db.insert('materials', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('[DB_V2] addMaterialV2 successful for item: ${expense.itemName}. Notifying listeners.');
      _notifyListeners();
    } catch (e) {
      debugPrint('[DB_V2] Error in addMaterialV2: $e');
      rethrow;
    }
  }

  /// Updates an existing material/expense from a JobMaterials model and notifies listeners.
  Future<void> updateMaterialV2(JobMaterials expense) async {
    final db = await database;
    try {
      await db.update(
        'materials',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      debugPrint('[DB_V2] updateMaterialV2 successful for item: ${expense.itemName}. Notifying listeners.');
      _notifyListeners();
    } catch (e) {
      debugPrint('[DB_V2] Error in updateMaterialV2: $e');
      rethrow;
    }
  }

  // --- V2 CRUD FOR EXPENSE CATEGORIES ---

  /// Adds a new expense category and notifies listeners. [1]
  Future<void> addExpenseCategoryV2(ExpenseCategory category) async {
    final db = await database;
    try {
      await db.insert('expense_categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('[DB_V2] addExpenseCategoryV2 successful for: ${category.name}. Notifying listeners.');
      _notifyListeners();
    } catch (e) {
      debugPrint('[DB_V2] Error in addExpenseCategoryV2: $e');
      rethrow;
    }
  }

  /// Updates an existing expense category and notifies listeners.
  Future<void> updateExpenseCategoryV2(ExpenseCategory category) async {
    final db = await database;
    try {
      await db.update('expense_categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
      debugPrint('[DB_V2] updateExpenseCategoryV2 successful for: ${category.name}. Notifying listeners.');
      _notifyListeners();
    } catch (e) {
      debugPrint('[DB_V2] Error in updateExpenseCategoryV2: $e');
      rethrow;
    }
  }

  // --- GENERIC V2 DELETE ---

  /// Deletes a record from a given table by its ID and notifies listeners.
  Future<void> deleteRecordV2({required int id, required String fromTable}) async {
    final db = await database;
    try {
      // For tables with `is_deleted` flag
      if (fromTable == 'time_entries' || fromTable == 'materials') {
        await db.update(fromTable, {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
        debugPrint('[DB_V2] Soft-deleted record id:$id from table:$fromTable. Notifying listeners.');
      }
      // For tables that have hard deletes (like expense_categories)
      else {
        await db.delete(fromTable, where: 'id = ?', whereArgs: [id]);
        debugPrint('[DB_V2] Hard-deleted record id:$id from table:$fromTable. Notifying listeners.');
      }
      _notifyListeners();
    } catch (e) {
      debugPrint('[DB_V2] Error in deleteRecordV2: $e');
      rethrow;
    }
  }

} // <--- End of DatabaseHelperV2 class


// ============================================================================
// |                            LEGACY CODE (FULLY RESTORED)                  |
// ============================================================================

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'time_tracker_pro.db');
    debugPrint('[DB_Legacy] Opening database at path: $path');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // This method is called by V2's _initDatabase to ensure schema is only created once.
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB_Legacy] Running _onCreate to build all tables...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, contact_person TEXT, phone_number TEXT)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (id INTEGER PRIMARY KEY AUTOINCREMENT, project_name TEXT NOT NULL, client_id INTEGER NOT NULL, location TEXT, pricing_model TEXT DEFAULT 'hourly', is_completed INTEGER NOT NULL DEFAULT 0, completion_date TEXT, is_internal INTEGER NOT NULL DEFAULT 0, billed_hourly_rate REAL, FOREIGN KEY (client_id) REFERENCES clients(id), UNIQUE(project_name, client_id))
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_number TEXT UNIQUE, name TEXT NOT NULL, title_id INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS time_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, employee_id INTEGER, start_time TEXT, end_time TEXT, paused_duration REAL NOT NULL DEFAULT 0.0, final_billed_duration_seconds REAL, is_paused INTEGER NOT NULL DEFAULT 0, pause_start_time TEXT, is_deleted INTEGER NOT NULL DEFAULT 0, work_details TEXT, FOREIGN KEY (project_id) REFERENCES projects(id), FOREIGN KEY (employee_id) REFERENCES employees(id))
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS materials (id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, item_name TEXT NOT NULL, cost REAL NOT NULL, purchase_date TEXT NOT NULL, description TEXT, is_deleted INTEGER NOT NULL DEFAULT 0, expense_category TEXT, unit TEXT, quantity REAL, base_quantity REAL, odometer_reading REAL, is_company_expense INTEGER NOT NULL DEFAULT 0, vehicle_designation TEXT, vendor_or_subtrade TEXT, FOREIGN KEY (project_id) REFERENCES projects(id))
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, standard_rate REAL NOT NULL DEFAULT 0.0)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL)
    ''');
  }

  Future<List<AllRecordViewModel>> getAllRecords() async {
    final db = await database;
    final List<AllRecordViewModel> allRecords = [];

    final timeEntryMaps = await db.query('time_entries', where: 'is_deleted = 0 AND start_time IS NOT NULL');
    for (var map in timeEntryMaps) {
      allRecords.add(AllRecordViewModel(
        id: map['id'] as int,
        type: RecordType.time,
        date: DateTime.parse(map['start_time'] as String),
        description: map['work_details'] as String? ?? 'No Details',
        value: (map['final_billed_duration_seconds'] as num? ?? 0.0) / 3600.0,
        categoryOrProject: 'Project ID: ${map['project_id']}',
      ));
    }

    final materialMaps = await db.query('materials', where: 'is_deleted = 0 AND purchase_date IS NOT NULL');
    for (var map in materialMaps) {
      allRecords.add(AllRecordViewModel(
        id: map['id'] as int,
        type: RecordType.expense,
        date: DateTime.parse(map['purchase_date'] as String),
        description: map['item_name'] as String? ?? 'Unnamed Item',
        value: (map['cost'] as num? ?? 0.0).toDouble(),
        categoryOrProject: map['expense_category'] as String? ?? 'Project ID: ${map['project_id']}',
      ));
    }

    allRecords.sort((a, b) => b.date.compareTo(a.date));
    return allRecords;
  }
}
