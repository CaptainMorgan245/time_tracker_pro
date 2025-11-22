// lib/settings_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/settings_model.dart';

class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  final _databaseHelper = DatabaseHelperV2.instance;
  final String tableName = 'settings';

  /// Checks if setup has been completed by checking the setup_completed flag.
  Future<bool> hasSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName, limit: 1);
    if (maps.isEmpty) return false;
    return (maps.first['setup_completed'] as int?) == 1;
  }

  /// Loads settings from the database.
  /// If no settings exist, it returns a default SettingsModel instance.
  Future<SettingsModel> loadSettings() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName, limit: 1);

    if (maps.isNotEmpty) {
      return SettingsModel.fromMap(maps.first);
    }
    // This should theoretically not be hit on subsequent runs, but it's safe to have.
    return SettingsModel();
  }

  /// Saves settings. Returns `true` if it was a new insert, `false` if it was an update.
  Future<bool> saveSettings(SettingsModel settings) async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> existingMaps = await db.query(tableName, limit: 1);
    final bool exists = existingMaps.isNotEmpty;

    if (exists) {
      // Update existing settings. The 'id' is always 1.
      await db.update(
        tableName,
        settings.toMap(),
        where: 'id = ?',
        whereArgs: [1],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return false; // Return FALSE because it was an update.
    } else {
      // Insert new settings for the very first time.
      // Ensure the first record has the static ID of 1.
      final settingsMap = settings.toMap();
      settingsMap['id'] = 1;

      await db.insert(
        tableName,
        settingsMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true; // Return TRUE because it was a new insert.
    }
  }
}