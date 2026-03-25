// lib/settings_service.dart

import 'package:drift/drift.dart' show Variable;
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/settings_model.dart';

class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  final String tableName = 'settings';

  /// Checks if setup has been completed by checking the setup_completed flag.
  Future<bool> hasSettings() async {
    final rows = await AppDatabase.instance
        .customSelect('SELECT * FROM $tableName LIMIT 1')
        .get();
    final maps = rows.map((r) => r.data).toList();
    if (maps.isEmpty) return false;
    return (maps.first['setup_completed'] as int?) == 1;
  }

  /// Loads settings from the database.
  /// If no settings exist, it returns a default SettingsModel instance.
  Future<SettingsModel> loadSettings() async {
    final rows = await AppDatabase.instance
        .customSelect('SELECT * FROM $tableName LIMIT 1')
        .get();
    final maps = rows.map((r) => r.data).toList();

    if (maps.isNotEmpty) {
      return SettingsModel.fromMap(maps.first);
    }
    // This should theoretically not be hit on subsequent runs, but it's safe to have.
    return SettingsModel();
  }

  /// Saves settings. Returns `true` if it was a new insert, `false` if it was an update.
  Future<bool> saveSettings(SettingsModel settings) async {
    final rows = await AppDatabase.instance
        .customSelect('SELECT * FROM $tableName LIMIT 1')
        .get();
    final maps = rows.map((r) => r.data).toList();
    final bool exists = maps.isNotEmpty;

    final settingsMap = settings.toMap();

    if (exists) {
      // Update existing settings. The 'id' is always 1.
      settingsMap.remove('id');
      final columns = settingsMap.keys.toList();
      final setClause = columns.map((c) => '$c = ?').join(', ');
      
      final vars = columns.map((c) {
        final val = settingsMap[c];
        // id and setup_completed are non-null in the database schema
        if (c == 'setup_completed') {
          return Variable.withInt(val as int);
        }
        // Use Variable(value) for all nullable fields as per instruction #6
        return Variable(val);
      }).toList();
      vars.add(Variable.withInt(1)); // for WHERE id = ?

      await AppDatabase.instance.customUpdate(
        'UPDATE $tableName SET $setClause WHERE id = ?',
        variables: vars,
        updates: {AppDatabase.instance.settings},
      );
      return false; // Return FALSE because it was an update.
    } else {
      // Insert new settings for the very first time.
      // Ensure the first record has the static ID of 1.
      settingsMap['id'] = 1;
      final columns = settingsMap.keys.toList();
      final placeholders = columns.map((_) => '?').join(', ');
      
      final vars = columns.map((c) {
        final val = settingsMap[c];
        if (c == 'id' || c == 'setup_completed') {
          return Variable.withInt(val as int);
        }
        return Variable(val);
      }).toList();

      await AppDatabase.instance.customInsert(
        'INSERT OR REPLACE INTO $tableName (${columns.join(', ')}) VALUES ($placeholders)',
        variables: vars,
        updates: {AppDatabase.instance.settings},
      );
      return true; // Return TRUE because it was a new insert.
    }
  }

  /// NEW: Method to retrieve the burden rate for the ProjectRepository
  Future<double> getBurdenRate() async {
    final settings = await loadSettings();
    // Return the stored burden rate, or fall back to 0.0 if still null
    return settings.burdenRate;
  }
}
