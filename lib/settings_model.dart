// lib/settings_model.dart

import 'dart:convert';

class SettingsModel {
  final int id;
  final String? employeeNumberPrefix;
  final int? nextEmployeeNumber;
  final List<String> vehicleDesignations;
  final List<String> vendors;

  SettingsModel({
    this.id = 1,
    this.employeeNumberPrefix,
    this.nextEmployeeNumber,
    // Fix applied earlier: using non-nullable defaults
    List<String>? vehicleDesignations,
    List<String>? vendors,
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
    );
  }
  // end method: fromMap

  // start method: toMap
  // FIX: Explicitly ensuring lists are serialized to JSON. This is where the failure is most likely.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number_prefix': employeeNumberPrefix,
      'next_employee_number': nextEmployeeNumber,
      'vehicle_designations': jsonEncode(vehicleDesignations),
      'vendors': jsonEncode(vendors),
    };
  }
  // end method: toMap

  SettingsModel copyWith({
    int? id,
    String? employeeNumberPrefix,
    int? nextEmployeeNumber,
    List<String>? vehicleDesignations,
    List<String>? vendors,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      employeeNumberPrefix: employeeNumberPrefix ?? this.employeeNumberPrefix,
      nextEmployeeNumber: nextEmployeeNumber ?? this.nextEmployeeNumber,
      vehicleDesignations: vehicleDesignations ?? this.vehicleDesignations,
      vendors: vendors ?? this.vendors,
    );
  }
}