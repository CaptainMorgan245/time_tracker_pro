// lib/settings_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/settings_model.dart';

class SettingsService {
  // Add a private constructor and a static instance
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  final _databaseHelper = DatabaseHelper.instance;
  final String tableName = 'settings';

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
