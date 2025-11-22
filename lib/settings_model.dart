// lib/settings_model.dart

import 'dart:convert';

class SettingsModel {
  final int id;
  final String? employeeNumberPrefix;
  final int? nextEmployeeNumber;
  final List<String> vehicleDesignations;
  final List<String> vendors;
  final double? companyHourlyRate;
  final double burdenRate;

  // New settings fields
  final int timeRoundingInterval; // 0 = no rounding, 15 or 30 minutes
  final int autoBackupReminderFrequency; // Show reminder every X app runs (0 = disabled)
  final int appRunsSinceBackup; // Counter for backup reminder
  final String measurementSystem; // 'metric' or 'imperial'
  final int defaultReportMonths; // Default lookback period for reports
  final bool setupCompleted; // Setup completion flag

  SettingsModel({
    this.id = 1,
    this.employeeNumberPrefix,
    this.nextEmployeeNumber,
    List<String>? vehicleDesignations,
    List<String>? vendors,
    this.companyHourlyRate,
    this.burdenRate = 0.0,
    this.timeRoundingInterval = 0,
    this.autoBackupReminderFrequency = 10,
    this.appRunsSinceBackup = 0,
    this.measurementSystem = 'metric',
    this.defaultReportMonths = 3,
    this.setupCompleted = false,
  }) : vehicleDesignations = vehicleDesignations ?? [],
        vendors = vendors ?? [];

  // start method: fromMap
  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    List<String> decodeList(dynamic data) {
      if (data == null || data is! String || data.isEmpty) return [];
      try {
        final decoded = jsonDecode(data);
        return List<String>.from(decoded ?? []);
      } catch (e) {
        return [];
      }
    }

    return SettingsModel(
      id: map['id'] ?? 1,
      employeeNumberPrefix: map['employee_number_prefix'],
      nextEmployeeNumber: map['next_employee_number'],
      vehicleDesignations: decodeList(map['vehicle_designations']),
      vendors: decodeList(map['vendors']),
      companyHourlyRate: map['company_hourly_rate'] != null
          ? (map['company_hourly_rate'] as num).toDouble()
          : null,
      burdenRate: (map['burden_rate'] as num?)?.toDouble() ?? 0.0,
      timeRoundingInterval: map['time_rounding_interval'] ?? 15,
      autoBackupReminderFrequency: map['auto_backup_reminder_frequency'] ?? 10,
      appRunsSinceBackup: map['app_runs_since_backup'] ?? 0,
      measurementSystem: map['measurement_system'] ?? 'metric',
      defaultReportMonths: map['default_report_months'] ?? 3,
      setupCompleted: (map['setup_completed'] as int?) == 1,
    );
  }
  // end method: fromMap

  // start method: toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number_prefix': employeeNumberPrefix,
      'next_employee_number': nextEmployeeNumber,
      'vehicle_designations': jsonEncode(vehicleDesignations),
      'vendors': jsonEncode(vendors),
      'company_hourly_rate': companyHourlyRate,
      'burden_rate': burdenRate,
      'time_rounding_interval': timeRoundingInterval,
      'auto_backup_reminder_frequency': autoBackupReminderFrequency,
      'app_runs_since_backup': appRunsSinceBackup,
      'measurement_system': measurementSystem,
      'default_report_months': defaultReportMonths,
      'setup_completed': setupCompleted ? 1 : 0,
    };
  }
  // end method: toMap

  // start method: copyWith
  SettingsModel copyWith({
    int? id,
    String? employeeNumberPrefix,
    int? nextEmployeeNumber,
    List<String>? vehicleDesignations,
    List<String>? vendors,
    double? companyHourlyRate,
    double? burdenRate,
    int? timeRoundingInterval,
    int? autoBackupReminderFrequency,
    int? appRunsSinceBackup,
    String? measurementSystem,
    int? defaultReportMonths,
    bool? setupCompleted,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      employeeNumberPrefix: employeeNumberPrefix ?? this.employeeNumberPrefix,
      nextEmployeeNumber: nextEmployeeNumber ?? this.nextEmployeeNumber,
      vehicleDesignations: vehicleDesignations ?? this.vehicleDesignations,
      vendors: vendors ?? this.vendors,
      companyHourlyRate: companyHourlyRate ?? this.companyHourlyRate,
      burdenRate: burdenRate ?? this.burdenRate,
      timeRoundingInterval: timeRoundingInterval ?? this.timeRoundingInterval,
      autoBackupReminderFrequency: autoBackupReminderFrequency ?? this.autoBackupReminderFrequency,
      appRunsSinceBackup: appRunsSinceBackup ?? this.appRunsSinceBackup,
      measurementSystem: measurementSystem ?? this.measurementSystem,
      defaultReportMonths: defaultReportMonths ?? this.defaultReportMonths,
      setupCompleted: setupCompleted ?? this.setupCompleted,
    );
  }
// end method: copyWith
}