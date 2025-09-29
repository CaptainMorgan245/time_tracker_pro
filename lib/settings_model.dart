// lib/settings_model.dart

import 'dart:convert';

class SettingsModel {
  final int id;
  final String? employeeNumberPrefix;
  final int? nextEmployeeNumber;
  final List<String> vehicleDesignations;
  final List<String> vendors;
  final double? companyHourlyRate;

  // New settings fields
  final int timeRoundingInterval; // 0 = no rounding, 15 or 30 minutes
  final int autoBackupReminderFrequency; // Show reminder every X app runs (0 = disabled)
  final int appRunsSinceBackup; // Counter for backup reminder
  final String measurementSystem; // 'metric' or 'imperial'
  final int defaultReportMonths; // Default lookback period for reports

  SettingsModel({
    this.id = 1,
    this.employeeNumberPrefix,
    this.nextEmployeeNumber,
    List<String>? vehicleDesignations,
    List<String>? vendors,
    this.companyHourlyRate,
    this.timeRoundingInterval = 0,
    this.autoBackupReminderFrequency = 10,
    this.appRunsSinceBackup = 0,
    this.measurementSystem = 'metric',
    this.defaultReportMonths = 3,
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
      timeRoundingInterval: map['time_rounding_interval'] ?? 15,
      autoBackupReminderFrequency: map['auto_backup_reminder_frequency'] ?? 10,
      appRunsSinceBackup: map['app_runs_since_backup'] ?? 0,
      measurementSystem: map['measurement_system'] ?? 'metric',
      defaultReportMonths: map['default_report_months'] ?? 3,
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
      'time_rounding_interval': timeRoundingInterval,
      'auto_backup_reminder_frequency': autoBackupReminderFrequency,
      'app_runs_since_backup': appRunsSinceBackup,
      'measurement_system': measurementSystem,
      'default_report_months': defaultReportMonths,
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
    int? timeRoundingInterval,
    int? autoBackupReminderFrequency,
    int? appRunsSinceBackup,
    String? measurementSystem,
    int? defaultReportMonths,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      employeeNumberPrefix: employeeNumberPrefix ?? this.employeeNumberPrefix,
      nextEmployeeNumber: nextEmployeeNumber ?? this.nextEmployeeNumber,
      vehicleDesignations: vehicleDesignations ?? this.vehicleDesignations,
      vendors: vendors ?? this.vendors,
      companyHourlyRate: companyHourlyRate ?? this.companyHourlyRate,
      timeRoundingInterval: timeRoundingInterval ?? this.timeRoundingInterval,
      autoBackupReminderFrequency: autoBackupReminderFrequency ?? this.autoBackupReminderFrequency,
      appRunsSinceBackup: appRunsSinceBackup ?? this.appRunsSinceBackup,
      measurementSystem: measurementSystem ?? this.measurementSystem,
      defaultReportMonths: defaultReportMonths ?? this.defaultReportMonths,
    );
  }
// end method: copyWith
}