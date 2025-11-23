// lib/services/settings_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_tracker_pro/models.dart';

class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  static const String _settingsKey = 'app_settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        return AppSettings.fromMap(settingsMap);
      } catch (e) {
        // Log error and return default
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
    return AppSettings.fromMap({
      'employee_number_prefix': 'EMP',
      'next_employee_number': 100,
      'vehicle_designations': 'Truck 1,Van 1,Excavator',  // ← STRING not List
      'vendors': 'Home Depot,Esso,Uline',                 // ← STRING not List
      'company_hourly_rate': 75.0,
      'burden_rate': 50.0,
      'time_rounding_interval': 15,
      'auto_backup_reminder_frequency': 10,
      'app_runs_since_backup': 0,
      'measurement_system': 'metric',
      'default_report_months': 3,
      'expense_markup_percentage': 0.0,
    });
  }

  // NEW: Method to retrieve the single required value for the ProjectRepository
  Future<double> getBurdenRate() async {
    final settings = await loadSettings();
    // Return the stored burden rate, or fall back to 50.0 if still null
    return settings.burdenRate ?? 50.0;
  }
}

// lib/services/settings_service.dart