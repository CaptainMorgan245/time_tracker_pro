// lib/settings_model.dart

class SettingsModel {
  final int id;
  final String? employeeNumberPrefix;
  final int? nextEmployeeNumber;
  final List<String>? vehicleDesignations;
  final List<String>? vendors;

  SettingsModel({
    this.id = 0,
    this.employeeNumberPrefix,
    this.nextEmployeeNumber,
    this.vehicleDesignations,
    this.vendors,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] ?? 0,
      employeeNumberPrefix: map['employee_number_prefix'],
      nextEmployeeNumber: map['next_employee_number'],
      vehicleDesignations: (map['vehicle_designations'] as List?)?.cast<String>(),
      vendors: (map['vendors'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number_prefix': employeeNumberPrefix,
      'next_employee_number': nextEmployeeNumber,
      'vehicle_designations': vehicleDesignations,
      'vendors': vendors,
    };
  }

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