// lib/settings_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
// FIX: Your model is named SettingsModel, not Settings. This keeps it correct.
import 'package:time_tracker_pro/settings_model.dart';

class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  // THE FIX: Point to DatabaseHelperV2
  final _databaseHelper = DatabaseHelperV2.instance;
  final String tableName = 'settings';

  Future<bool> hasSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return maps.isNotEmpty;
  }

  Future<SettingsModel> loadSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    if (maps.isNotEmpty) {
      return SettingsModel.fromMap(maps.first);
    }
    // Return a default SettingsModel instance when empty
    return SettingsModel();
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final db = await _databaseHelper.database;

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
    // Settings changes rarely need immediate UI notification, so notifyDatabaseChanged() is omitted.
  }
}
