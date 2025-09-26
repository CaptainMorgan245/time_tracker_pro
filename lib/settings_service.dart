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

  // start method: loadSettings
  // FIX 1: Change return type to non-nullable (SettingsModel)
  Future<SettingsModel> loadSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    if (maps.isNotEmpty) {
      return SettingsModel.fromMap(maps.first);
    }
    // FIX 2: Return a default SettingsModel instance when empty,
    // preventing all null-related crashes in the calling screen.
    return SettingsModel();
  }
  // end method: loadSettings

  // start method: saveSettings
  Future<void> saveSettings(SettingsModel settings) async {
    final db = await _databaseHelper.database;

    // FIX 3: Use robust update-or-insert logic for the single settings row.
    final exists = await hasSettings();
    if (exists) {
      await db.update(
        tableName,
        settings.toMap(),
        where: 'id = ?',
        whereArgs: [1], // Targets the single settings row
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.insert(
        tableName,
        settings.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
// end method: saveSettings
}