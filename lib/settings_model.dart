// lib/settings_model.dart

class SettingsModel {
  final int id;
  final String? employeeNumberPrefix;
  final int? nextEmployeeNumber;

  SettingsModel({
    this.id = 0,
    this.employeeNumberPrefix,
    this.nextEmployeeNumber,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] ?? 0,
      employeeNumberPrefix: map['employee_number_prefix'],
      nextEmployeeNumber: map['next_employee_number'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number_prefix': employeeNumberPrefix,
      'next_employee_number': nextEmployeeNumber,
    };
  }

  SettingsModel copyWith({
    int? id,
    String? employeeNumberPrefix,
    int? nextEmployeeNumber,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      employeeNumberPrefix: employeeNumberPrefix ?? this.employeeNumberPrefix,
      nextEmployeeNumber: nextEmployeeNumber ?? this.nextEmployeeNumber,
    );
  }
}