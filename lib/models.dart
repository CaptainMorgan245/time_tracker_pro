// lib/models.dart

// FIX 1: Import the equatable package
import 'package:equatable/equatable.dart';

// start class: Client
// FIX 2: Extend Equatable
class Client extends Equatable {
  final int? id;
  final String name;
  final bool isActive;
  final String? contactPerson;
  final String? phoneNumber;

  const Client({
    this.id,
    required this.name,
    this.isActive = true,
    this.contactPerson,
    this.phoneNumber,
  });

  // FIX 3: Add props for Equatable comparison
  @override
  List<Object?> get props => [id];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'contact_person': contactPerson,
      'phone_number': phoneNumber,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] == 1,
      contactPerson: map['contact_person'],
      phoneNumber: map['phone_number'],
    );
  }

  Client copyWith({
    int? id,
    String? name,
    bool? isActive,
    String? contactPerson,
    String? phoneNumber,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      contactPerson: contactPerson ?? this.contactPerson,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
// end class: Client

// start class: Project
// FIX 4: Extend Equatable
class Project extends Equatable {
  final int? id;
  final String projectName;
  final int clientId;
  final String? location;
  final String? pricingModel;
  final bool isCompleted;
  final DateTime? completionDate;
  final bool isInternal;
  final double? billedHourlyRate;

  const Project({
    this.id,
    required this.projectName,
    required this.clientId,
    this.location,
    this.pricingModel,
    this.isCompleted = false,
    this.completionDate,
    this.isInternal = false,
    this.billedHourlyRate,
  });

  // FIX 5: Add props for Equatable comparison
  @override
  List<Object?> get props => [id];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_name': projectName,
      'client_id': clientId,
      'location': location,
      'pricing_model': pricingModel,
      'is_completed': isCompleted ? 1 : 0,
      'completion_date': completionDate?.toIso8601String(),
      'is_internal': isInternal ? 1 : 0,
      'billed_hourly_rate': billedHourlyRate,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      projectName: map['project_name'],
      clientId: map['client_id'],
      location: map['location'],
      pricingModel: map['pricing_model'],
      isCompleted: map['is_completed'] == 1,
      completionDate: map['completion_date'] != null ? DateTime.parse(map['completion_date']) : null,
      isInternal: map['is_internal'] == 1,
      billedHourlyRate: map['billed_hourly_rate'],
    );
  }

  Project copyWith({
    int? id,
    String? projectName,
    int? clientId,
    String? location,
    String? pricingModel,
    bool? isCompleted,
    DateTime? completionDate,
    bool? isInternal,
    double? billedHourlyRate,
  }) {
    return Project(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      clientId: clientId ?? this.clientId,
      location: location ?? this.location,
      pricingModel: pricingModel ?? this.pricingModel,
      isCompleted: isCompleted ?? this.isCompleted,
      completionDate: completionDate ?? this.completionDate,
      isInternal: isInternal ?? this.isInternal,
      billedHourlyRate: billedHourlyRate ?? this.billedHourlyRate,
    );
  }
}
// end class: Project

// start class: Employee
// FIX 6: Extend Equatable
class Employee extends Equatable {
  final int? id;
  final String? employeeNumber;
  final String name;
  final int? titleId;
  final bool isDeleted;

  const Employee({
    this.id,
    this.employeeNumber,
    required this.name,
    this.titleId,
    this.isDeleted = false,
  });

  // FIX 7: Add props for Equatable comparison
  @override
  List<Object?> get props => [id];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number': employeeNumber,
      'name': name,
      'title_id': titleId,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      employeeNumber: map['employee_number'],
      name: map['name'],
      titleId: map['title_id'],
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Employee copyWith({
    int? id,
    String? employeeNumber,
    String? name,
    int? titleId,
    bool? isDeleted,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      name: name ?? this.name,
      titleId: titleId ?? this.titleId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
// end class: Employee

// start class: TimeEntry
class TimeEntry {
  final int? id;
  final int projectId;
  final int? employeeId;
  final DateTime? startTime;
  final DateTime? endTime;
  final double pausedDuration;
  final double? finalBilledDurationSeconds;
  final bool isPaused;
  final DateTime? pauseStartTime;
  final bool isDeleted;
  final String? workDetails;

  TimeEntry({
    this.id,
    required this.projectId,
    this.employeeId,
    this.startTime,
    this.endTime,
    this.pausedDuration = 0.0,
    this.finalBilledDurationSeconds,
    this.isPaused = false,
    this.pauseStartTime,
    this.isDeleted = false,
    this.workDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'employee_id': employeeId,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'paused_duration': pausedDuration,
      'final_billed_duration_seconds': finalBilledDurationSeconds,
      'is_paused': isPaused ? 1 : 0,
      'pause_start_time': pauseStartTime?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'work_details': workDetails,
    };
  }

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      id: map['id'],
      projectId: map['project_id'],
      employeeId: map['employee_id'],
      startTime: map['start_time'] != null ? DateTime.parse(map['start_time']) : null,
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      pausedDuration: map['paused_duration'],
      finalBilledDurationSeconds: map['final_billed_duration_seconds'],
      isPaused: map['is_paused'] == 1,
      pauseStartTime: map['pause_start_time'] != null ? DateTime.parse(map['pause_start_time']) : null,
      isDeleted: map['is_deleted'] == 1,
      workDetails: map['work_details'],
    );
  }

  TimeEntry copyWith({
    int? id,
    int? projectId,
    int? employeeId,
    DateTime? startTime,
    DateTime? endTime,
    double? pausedDuration,
    double? finalBilledDurationSeconds,
    bool? isPaused,
    DateTime? pauseStartTime,
    bool? isDeleted,
    String? workDetails,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      employeeId: employeeId ?? this.employeeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      finalBilledDurationSeconds: finalBilledDurationSeconds ?? this.finalBilledDurationSeconds,
      isPaused: isPaused ?? this.isPaused,
      pauseStartTime: pauseStartTime ?? this.pauseStartTime,
      isDeleted: isDeleted ?? this.isDeleted,
      workDetails: workDetails ?? this.workDetails,
    );
  }
}
// end class: TimeEntry

// start class: JobMaterials
class JobMaterials {
  final int? id;
  final int projectId;
  final String itemName;
  final double cost;
  final DateTime purchaseDate;
  final String? description;
  final bool isDeleted;
  final String? expenseCategory;
  final String? unit;
  final double? quantity;
  final double? baseQuantity;
  final double? odometerReading;
  final bool isCompanyExpense;
  final String? vehicleDesignation;
  final String? vendorOrSubtrade;

  JobMaterials({
    this.id,
    required this.projectId,
    required this.itemName,
    required this.cost,
    required this.purchaseDate,
    this.description,
    this.isDeleted = false,
    this.expenseCategory,
    this.unit,
    this.quantity,
    this.baseQuantity,
    this.odometerReading,
    this.isCompanyExpense = false,
    this.vehicleDesignation,
    this.vendorOrSubtrade,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'item_name': itemName,
      'cost': cost,
      'purchase_date': purchaseDate.toIso8601String(),
      'description': description,
      'is_deleted': isDeleted ? 1 : 0,
      'expense_category': expenseCategory,
      'unit': unit,
      'quantity': quantity,
      'base_quantity': baseQuantity,
      'odometer_reading': odometerReading,
      'is_company_expense': isCompanyExpense ? 1 : 0,
      'vehicle_designation': vehicleDesignation,
      'vendor_or_subtrade': vendorOrSubtrade,
    };
  }

  factory JobMaterials.fromMap(Map<String, dynamic> map) {
    return JobMaterials(
      id: map['id'],
      projectId: map['project_id'],
      itemName: map['item_name'],
      cost: map['cost'],
      purchaseDate: DateTime.parse(map['purchase_date']),
      description: map['description'],
      isDeleted: map['is_deleted'] == 1,
      expenseCategory: map['expense_category'],
      unit: map['unit'],
      quantity: map['quantity'],
      baseQuantity: map['base_quantity'],
      odometerReading: map['odometer_reading'],
      isCompanyExpense: map['is_company_expense'] == 1,
      vehicleDesignation: map['vehicle_designation'],
      vendorOrSubtrade: map['vendor_or_subtrade'],
    );
  }

  JobMaterials copyWith({
    int? id,
    int? projectId,
    String? itemName,
    double? cost,
    DateTime? purchaseDate,
    String? description,
    bool? isDeleted,
    String? expenseCategory,
    String? unit,
    double? quantity,
    double? baseQuantity,
    double? odometerReading,
    bool? isCompanyExpense,
    String? vehicleDesignation,
    String? vendorOrSubtrade,
  }) {
    return JobMaterials(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      itemName: itemName ?? this.itemName,
      cost: cost ?? this.cost,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      description: description ?? this.description,
      isDeleted: isDeleted ?? this.isDeleted,
      expenseCategory: expenseCategory ?? this.expenseCategory,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      odometerReading: odometerReading ?? this.odometerReading,
      isCompanyExpense: isCompanyExpense ?? this.isCompanyExpense,
      vehicleDesignation: vehicleDesignation ?? this.vehicleDesignation,
      vendorOrSubtrade: vendorOrSubtrade ?? this.vendorOrSubtrade,
    );
  }
}
// end class: JobMaterials

// start class: AppSettings
class AppSettings {
  final Map<String, dynamic> settings;

  AppSettings({required this.settings});

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(settings: map);
  }

  Map<String, dynamic> toMap() {
    return settings;
  }
}
// end class: AppSettings

// start class: Role
class Role {
  final int? id;
  final String name;
  final double standardRate;

  Role({
    this.id,
    required this.name,
    this.standardRate = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'standard_rate': standardRate,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'],
      name: map['name'],
      standardRate: map['standard_rate'],
    );
  }

  Role copyWith({
    int? id,
    String? name,
    double? standardRate,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      standardRate: standardRate ?? this.standardRate,
    );
  }
}
// end class: Role

// start class: ExpenseCategory
class ExpenseCategory {
  final int? id;
  final String name;

  ExpenseCategory({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'],
      name: map['name'],
    );
  }

  ExpenseCategory copyWith({
    int? id,
    String? name,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
// end class: ExpenseCategory

// start cost summary class
class CostSummary {
  final String categoryName;
  final double totalCost;
  final int recordCount;

  CostSummary({
    required this.categoryName,
    required this.totalCost,
    required this.recordCount,
  });
}
// end method: cost summary

// start class: User
class User {
  final int? id;
  final String username;
  final String passwordHash;
  final bool isActive;
  final bool isAdmin;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    this.isActive = true,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'is_active': isActive ? 1 : 0,
      'is_admin': isAdmin ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      isActive: map['is_active'] == 1,
      isAdmin: map['is_admin'] == 1,
    );
  }
}
// end class: User


// =========================================================================
// == ADDED FOR DATABASE VIEWER TEST ==
// =========================================================================

enum RecordType {
  time,
  expense,
}

class AllRecordViewModel {
  final int id;
  final RecordType type;
  final DateTime date;
  final String description;
  final double value; // Can be hours for time, or cost for expense
  final String categoryOrProject;

  AllRecordViewModel({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    required this.value,
    required this.categoryOrProject,
  });
}

