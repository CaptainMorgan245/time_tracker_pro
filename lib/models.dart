// lib/models.dart

// ============================================================================
// |                         DATA MODELS (WITH copyWith)                      |
// ============================================================================

class Client {
  final int? id;
  final String name;
  final bool isActive;
  final String? contactPerson;
  final String? phoneNumber;

  Client({
    this.id,
    required this.name,
    this.isActive = true,
    this.contactPerson,
    this.phoneNumber,
  });

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

  @override
  String toString() {
    return 'Client(id: $id, name: $name, isActive: $isActive)';
  }
}

class Project {
  final int? id;
  final String projectName;
  final int clientId;
  final String? location;
  final String pricingModel; // 'hourly', 'fixed'
  final bool isCompleted;
  final DateTime? completionDate;
  final bool isInternal;
  final double? billedHourlyRate;
  final double? fixedPrice;

  const Project({
    this.id,
    required this.projectName,
    required this.clientId,
    this.location,
    required this.pricingModel,
    this.isCompleted = false,
    this.completionDate,
    this.isInternal = false,
    this.billedHourlyRate,
    this.fixedPrice,
  });

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
      'project_price': fixedPrice,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      projectName: map['project_name'],
      clientId: map['client_id'],
      location: map['location'],
      pricingModel: map['pricing_model'] ?? 'hourly',
      isCompleted: map['is_completed'] == 1,
      completionDate: map['completion_date'] != null
          ? DateTime.tryParse(map['completion_date'])
          : null,
      isInternal: map['is_internal'] == 1,
      billedHourlyRate: (map['billed_hourly_rate'] as num?)?.toDouble(),
      fixedPrice: (map['project_price'] as num?)?.toDouble(),
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
    double? fixedPrice,
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
      fixedPrice: fixedPrice ?? this.fixedPrice,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Project(id: $id, name: $projectName, clientId: $clientId, pricingModel: $pricingModel, fixedPrice: $fixedPrice)';
  }
}

class Employee {
  final int? id;
  final String? employeeNumber;
  final String name;
  final int? titleId;
  final bool isDeleted;

  Employee({
    this.id,
    this.employeeNumber,
    required this.name,
    this.titleId,
    this.isDeleted = false,
  });

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

class EmployeeSummaryViewModel {
  final String employeeName;
  final String employeeNumber;
  final String roleTitle;
  final int projectsCount;
  final double totalHours;
  final double totalBilledValue;

  EmployeeSummaryViewModel({
    required this.employeeName,
    required this.employeeNumber,
    required this.roleTitle,
    required this.projectsCount,
    required this.totalHours,
    required this.totalBilledValue,
  });

  @override
  String toString() {
    return 'EmployeeSummaryViewModel(employeeName: $employeeName, employeeNumber: $employeeNumber, roleTitle: $roleTitle, projectsCount: $projectsCount, totalHours: ${totalHours.toStringAsFixed(2)}, totalBilledValue: ${totalBilledValue.toStringAsFixed(2)})';
  }
}

class TimeEntry {
  final int? id;
  final int projectId;
  final int? employeeId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration pausedDuration;
  final double? finalBilledDurationSeconds;
  final bool isPaused;
  final DateTime? pauseStartTime;
  final bool isDeleted;
  final String? workDetails;

  TimeEntry({
    this.id,
    required this.projectId,
    this.employeeId,
    required this.startTime,
    this.endTime,
    this.pausedDuration = Duration.zero,
    this.finalBilledDurationSeconds,
    this.isPaused = false,
    this.pauseStartTime,
    this.isDeleted = false,
    this.workDetails,
  });

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      id: map['id'],
      projectId: map['project_id'],
      employeeId: map['employee_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime:
      map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      // FIX: Correctly parse duration from double
      pausedDuration: Duration(microseconds: ((map['paused_duration'] as num? ?? 0.0) * 1000000).round()),
      finalBilledDurationSeconds:
      (map['final_billed_duration_seconds'] as num?)?.toDouble(),
      isPaused: map['is_paused'] == 1,
      pauseStartTime: map['pause_start_time'] != null
          ? DateTime.parse(map['pause_start_time'])
          : null,
      isDeleted: map['is_deleted'] == 1,
      workDetails: map['work_details'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'employee_id': employeeId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      // FIX: Correctly store duration as double
      'paused_duration': pausedDuration.inMicroseconds / 1000000.0,
      'final_billed_duration_seconds': finalBilledDurationSeconds,
      'is_paused': isPaused ? 1 : 0,
      'pause_start_time': pauseStartTime?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'work_details': workDetails,
    };
  }

  TimeEntry copyWith({
    int? id,
    int? projectId,
    int? employeeId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? pausedDuration,
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
      cost: (map['cost'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchase_date']),
      description: map['description'],
      isDeleted: map['is_deleted'] == 1,
      expenseCategory: map['expense_category'],
      unit: map['unit'],
      quantity: (map['quantity'] as num?)?.toDouble(),
      baseQuantity: (map['base_quantity'] as num?)?.toDouble(),
      odometerReading: (map['odometer_reading'] as num?)?.toDouble(),
      isCompanyExpense: map['is_company_expense'] == 1,
      vehicleDesignation: map['vehicle_designation'],
      vendorOrSubtrade: map['vendor_or_subtrade'],
    );
  }
}

class ExpenseCategory {
  final int? id;
  final String name;

  ExpenseCategory({this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) =>
      ExpenseCategory(id: map['id'], name: map['name']);

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

class Role {
  final int? id;
  final String name;
  final double standardRate;

  Role({this.id, required this.name, this.standardRate = 0.0});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'standard_rate': standardRate};

  factory Role.fromMap(Map<String, dynamic> map) => Role(
      id: map['id'],
      name: map['name'],
      standardRate: (map['standard_rate'] as num? ?? 0.0).toDouble());

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

class AppSettings {
  final int id;
  final String? employeeNumberPrefix;
  final int? nextEmployeeNumber;
  final List<String> vehicleDesignations;
  final List<String> vendors;
  final double? companyHourlyRate;
  final double? burdenRate;
  final int? timeRoundingInterval;
  final int? autoBackupReminderFrequency;
  final int? appRunsSinceBackup;
  final String? measurementSystem;
  final int? defaultReportMonths;

  AppSettings({
    this.id = 1,
    this.employeeNumberPrefix,
    this.nextEmployeeNumber,
    this.vehicleDesignations = const [],
    this.vendors = const [],
    this.companyHourlyRate,
    this.burdenRate,
    this.timeRoundingInterval,
    this.autoBackupReminderFrequency,
    this.appRunsSinceBackup,
    this.measurementSystem,
    this.defaultReportMonths,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] ?? 1,
      employeeNumberPrefix: map['employee_number_prefix'],
      nextEmployeeNumber: map['next_employee_number'],
      vehicleDesignations: (map['vehicle_designations'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      vendors: (map['vendors'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      companyHourlyRate: (map['company_hourly_rate'] as num?)?.toDouble(),
      burdenRate: (map['burden_rate'] as num?)?.toDouble(),
      timeRoundingInterval: map['time_rounding_interval'],
      autoBackupReminderFrequency: map['auto_backup_reminder_frequency'],
      appRunsSinceBackup: map['app_runs_since_backup'],
      measurementSystem: map['measurement_system'],
      defaultReportMonths: map['default_report_months'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number_prefix': employeeNumberPrefix,
      'next_employee_number': nextEmployeeNumber,
      'vehicle_designations': vehicleDesignations.join(','),
      'vendors': vendors.join(','),
      'company_hourly_rate': companyHourlyRate,
      'burden_rate': burdenRate,
      'time_rounding_interval': timeRoundingInterval,
      'auto_backup_reminder_frequency': autoBackupReminderFrequency,
      'app_runs_since_backup': appRunsSinceBackup,
      'measurement_system': measurementSystem,
      'default_report_months': defaultReportMonths,
    };
  }
}

// For the main dashboard screen
enum RecordType { time, expense, payment }

class AllRecordViewModel {
  final int id;
  final RecordType type;
  final DateTime date;
  final String description;
  final double value; // Can be hours for time, or amount for cost/payment
  final String categoryOrProject;

  AllRecordViewModel({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    required this.value,
    required this.categoryOrProject,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AllRecordViewModel &&
        other.id == id &&
        other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

class CostSummary {
  final String categoryName;
  final double totalCost;
  final int recordCount;

  CostSummary({
    required this.categoryName,
    required this.totalCost,
    required this.recordCount,
  });

  CostSummary copyWith({
    String? categoryName,
    double? totalCost,
    int? recordCount,
  }) {
    return CostSummary(
      categoryName: categoryName ?? this.categoryName,
      totalCost: totalCost ?? this.totalCost,
      recordCount: recordCount ?? this.recordCount,
    );
  }

  @override
  String toString() {
    return 'CostSummary(category: $categoryName, cost: $totalCost, count: $recordCount)';
  }
}

// ============================================================================
// | PROJECT SUMMARY VIEW MODEL FOR ANALYTICS CARD & REPORT TABLE             |
// ============================================================================
// The required view model for analytics reports
class ProjectSummaryViewModel {
  final int projectId;
  final String projectName;
  final String pricingModel;
  final double billedRate;
  final double totalHours;
  final double totalExpenses;
  final double totalLabourCost;
  final double totalBilledValue;
  final String? clientName;
  final double profitLoss;

  const ProjectSummaryViewModel({
    required this.projectId,
    required this.projectName,
    required this.pricingModel,
    required this.billedRate,
    required this.totalHours,
    required this.totalExpenses,
    required this.totalLabourCost,
    required this.totalBilledValue,
    required this.clientName,
    required this.profitLoss,
  });

  @override
  String toString() {
    return 'ProjectSummary(name: $projectName, Hours: ${totalHours.toStringAsFixed(2)}, Expenses: ${totalExpenses.toStringAsFixed(2)}, P/L: ${profitLoss.toStringAsFixed(2)})';
  }
}

// ============================================================================
// | DROPDOWN ITEM (MODEL CONSOLIDATION FIX)                                  |
// ============================================================================
// This must be defined here and REMOVED from dropdown_repository.dart
class DropdownItem {
  final int id;
  final String name;
  const DropdownItem({required this.id, required this.name});
}