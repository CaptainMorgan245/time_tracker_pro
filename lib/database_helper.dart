// lib/database_helper.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker_pro/models.dart';

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
    debugPrint('[DatabaseHelper] Opening database at path: $path');
    // Using version 2 to ensure onUpgrade/onCreate logic can be triggered if needed in the future.
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  /// THIS IS THE COMPLETE _onCreate METHOD WITH ALL YOUR TABLES
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DatabaseHelper] Running _onCreate to build all tables...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT UNIQUE NOT NULL, 
        is_active INTEGER NOT NULL DEFAULT 1, 
        contact_person TEXT, 
        phone_number TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        project_name TEXT NOT NULL, 
        client_id INTEGER NOT NULL, 
        location TEXT, 
        pricing_model TEXT DEFAULT 'hourly', 
        is_completed INTEGER NOT NULL DEFAULT 0, 
        completion_date TEXT, 
        is_internal INTEGER NOT NULL DEFAULT 0, 
        billed_hourly_rate REAL, 
        FOREIGN KEY (client_id) REFERENCES clients(id), 
        UNIQUE(project_name, client_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        employee_number TEXT UNIQUE, 
        name TEXT NOT NULL, 
        title_id INTEGER, 
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        project_id INTEGER NOT NULL, 
        employee_id INTEGER, 
        start_time TEXT, 
        end_time TEXT, 
        paused_duration REAL NOT NULL DEFAULT 0.0, 
        final_billed_duration_seconds REAL, 
        is_paused INTEGER NOT NULL DEFAULT 0, 
        pause_start_time TEXT, 
        is_deleted INTEGER NOT NULL DEFAULT 0, 
        work_details TEXT, 
        FOREIGN KEY (project_id) REFERENCES projects(id), 
        FOREIGN KEY (employee_id) REFERENCES employees(id)
      )
    ''');
    // This correctly uses your JobMaterials model's structure
    await db.execute('''
      CREATE TABLE IF NOT EXISTS materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        cost REAL NOT NULL,
        purchase_date TEXT NOT NULL, 
        description TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        expense_category TEXT,
        unit TEXT,
        quantity REAL,
        base_quantity REAL,
        odometer_reading REAL,
        is_company_expense INTEGER NOT NULL DEFAULT 0,
        vehicle_designation TEXT,
        vendor_or_subtrade TEXT,
        FOREIGN KEY (project_id) REFERENCES projects(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT UNIQUE NOT NULL, 
        standard_rate REAL NOT NULL DEFAULT 0.0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT UNIQUE NOT NULL
      )
    ''');
  }

  /// This is the key function for our test.
  /// It reads from `time_entries` and `materials`.
  Future<List<AllRecordViewModel>> getAllRecords() async {
    final db = await database;
    final List<AllRecordViewModel> allRecords = [];

    // Part 1: Get Time Entries
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

    // Part 2: Get Materials
    // **THIS IS THE FIX:** It correctly queries 'purchase_date'.
    final materialMaps = await db.query('materials', where: 'is_deleted = 0 AND purchase_date IS NOT NULL');
    for (var map in materialMaps) {
      allRecords.add(AllRecordViewModel(
        id: map['id'] as int,
        type: RecordType.expense,
        date: DateTime.parse(map['purchase_date'] as String), // <-- The fix
        description: map['item_name'] as String? ?? 'Unnamed Item',
        value: (map['cost'] as num? ?? 0.0).toDouble(),
        categoryOrProject: map['expense_category'] as String? ?? 'Project ID: ${map['project_id']}',
      ));
    }

    allRecords.sort((a, b) => b.date.compareTo(a.date));
    return allRecords;
  }
}
