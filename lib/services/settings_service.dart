// lib/services/settings_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_tracker_pro/models.dart';

class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  static const String _settingsKey = 'app_settings';

  Future<AppSettings?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        // The AppSettings model in models.dart has fromMap and toMap
        // that handle simple key/value pairs. This seems inconsistent
        // with the complex object structure below. We will use a more
        // flexible Map<String, dynamic> for now.
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        // We will return a temporary AppSettings object for compatibility
        // but the real data is in the map.
        return AppSettings.fromMap(settingsMap);
      } catch (e) {
        // Handle error or return default
        return _createDefaultSettings();
      }
    }
    return _createDefaultSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final String settingsJson = jsonEncode(settings.toMap());
    await prefs.setString(_settingsKey, settingsJson);
  }

  AppSettings _createDefaultSettings() {
    // This creates a default structure.
    return AppSettings.fromMap({
      'employee_number_prefix': 'EMP',
      'next_employee_number': 100,
      'vehicle_designations': ['Truck 1', 'Van 1', 'Excavator'],
      'vendors': ['Home Depot', 'Esso', 'Uline'],
      'company_hourly_rate': 75.0,
      'time_rounding_interval': 15,
      'auto_backup_reminder_frequency': 10,
      'app_runs_since_backup': 0,
      'measurement_system': 'metric',
      'default_report_months': 3
    });
  }
}
