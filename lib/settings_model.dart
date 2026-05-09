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
  final String measurementSystem; // 'metric' or 'imperial'
  final double expenseMarkupPercentage;
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
    this.measurementSystem = 'metric',
    this.expenseMarkupPercentage = 0.0,
    this.setupCompleted = false,
  }) : vehicleDesignations = vehicleDesignations ?? [],
        vendors = vendors ?? [];

  // start method: fromMap
  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    List<String> decodeList(dynamic data) {
      if (data == null || data is! String || data.isEmpty) return [];
      return data.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
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
      measurementSystem: map['measurement_system'] ?? 'metric',
      setupCompleted: (map['setup_completed'] as int?) == 1,
      expenseMarkupPercentage: (map['expense_markup_percentage'] as num?)?.toDouble() ?? 0.0,
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
      'measurement_system': measurementSystem,
      'setup_completed': setupCompleted ? 1 : 0,
      'expense_markup_percentage': expenseMarkupPercentage,
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
    String? measurementSystem,
    double? expenseMarkupPercentage,
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
      measurementSystem: measurementSystem ?? this.measurementSystem,
      expenseMarkupPercentage: expenseMarkupPercentage ?? this.expenseMarkupPercentage,
      setupCompleted: setupCompleted ?? this.setupCompleted,
    );
  }
// end method: copyWith

  double applyTimeRounding(double seconds) {
    if (timeRoundingInterval == 0) {
      return seconds;
    }
    return (seconds / (timeRoundingInterval * 60)).round() * (timeRoundingInterval * 60).toDouble();
  }
}
