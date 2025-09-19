// lib/settings_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/settings_model.dart';

class SettingsService {
  final _databaseHelper = DatabaseHelper();
  final String tableName = 'settings';

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName(
        id INTEGER PRIMARY KEY,
        employee_number_prefix TEXT,
        next_employee_number INTEGER
      )
    ''');
  }

  Future<bool> hasSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return maps.isNotEmpty;
  }

  Future<SettingsModel?> loadSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    if (maps.isNotEmpty) {
      return SettingsModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final db = await _databaseHelper.database;
    await db.insert(
      tableName,
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}