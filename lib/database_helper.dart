// lib/database_helper.dart

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker_pro/models.dart';

class DatabaseHelper {
  // Make this a private constructor and expose a static instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'time_tracker_pro.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create Clients table
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        contact_person TEXT,
        phone_number TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create Roles table
    await db.execute('''
      CREATE TABLE roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        standard_rate REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Create Employees table
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_number TEXT UNIQUE,
        name TEXT NOT NULL,
        title_id INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (title_id) REFERENCES roles(id) ON DELETE SET NULL
      )
    ''');

    // Create Projects table
    await db.execute('''
      CREATE TABLE projects (
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

    // Create TimeEntries table
    await db.execute('''
      CREATE TABLE time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER,
        employee_id INTEGER,
        start_time TEXT NOT NULL,
        end_time TEXT,
        paused_duration REAL NOT NULL DEFAULT 0.0,
        final_billed_duration_seconds REAL,
        is_paused INTEGER NOT NULL DEFAULT 0,
        pause_start_time TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        work_details TEXT,
        FOREIGN KEY (project_id) REFERENCES projects(id),
        FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
      )
    ''');

    // Create Materials table
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER,
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

    // Create ExpenseCategories table
    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      )
    ''');

    // Create Settings table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        employee_number_prefix TEXT,
        next_employee_number INTEGER
      )
    ''');
  }
}