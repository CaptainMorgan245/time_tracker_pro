// lib/models.dart

export 'models/invoice.dart';
export 'models/company_settings.dart';

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
  final String? streetAddress;
  final String? region;
  final String? postalCode;
  final String pricingModel;
  final bool isCompleted;
  final DateTime? completionDate;
  final bool isInternal;
  final double? billedHourlyRate;
  final double? fixedPrice;
  final double expenseMarkupPercentage;
  final double taxRate;
  final int? parentProjectId;

  const Project({
    this.id,
    required this.projectName,
    required this.clientId,
    this.location,
    this.streetAddress,
    this.region,
    this.postalCode,
    required this.pricingModel,
    this.isCompleted = false,
    this.completionDate,
    this.isInternal = false,
    this.billedHourlyRate,
    this.fixedPrice,
    this.expenseMarkupPercentage = 15.0,
    this.taxRate = 5.0,
    this.parentProjectId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_name': projectName,
      'client_id': clientId,
      'location': location,
      'street_address': streetAddress,
      'region': region,
      'postal_code': postalCode,
      'pricing_model': pricingModel,
      'is_completed': isCompleted ? 1 : 0,
      'completion_date': completionDate?.toIso8601String(),
      'is_internal': isInternal ? 1 : 0,
      'billed_hourly_rate': billedHourlyRate,
      'project_price': fixedPrice,
      'expense_markup_percentage': expenseMarkupPercentage,
      'tax_rate': taxRate,
      'parent_project_id': parentProjectId,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      projectName: map['project_name'],
      clientId: map['client_id'],
      location: map['location'],
      streetAddress: map['street_address'] as String?,
      region: map['region'] as String?,
      postalCode: map['postal_code'] as String?,
      pricingModel: map['pricing_model'] ?? 'hourly',
      isCompleted: map['is_completed'] == 1,
      completionDate: map['completion_date'] != null ? DateTime.tryParse(map['completion_date']) : null,
      isInternal: map['is_internal'] == 1,
      billedHourlyRate: (map['billed_hourly_rate'] as num?)?.toDouble(),
      fixedPrice: (map['project_price'] as num?)?.toDouble(),
      expenseMarkupPercentage: (map['expense_markup_percentage'] as num?)?.toDouble() ?? 15.0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 5.0,
      parentProjectId: map['parent_project_id'] as int?,
    );
  }

  Project copyWith({
    int? id,
    String? projectName,
    int? clientId,
    String? location,
    String? streetAddress,
    String? region,
    String? postalCode,
    String? pricingModel,
    bool? isCompleted,
    DateTime? completionDate,
    bool? isInternal,
    double? billedHourlyRate,
    double? fixedPrice,
    double? expenseMarkupPercentage,
    double? taxRate,
    int? parentProjectId,
  }) {
    return Project(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      clientId: clientId ?? this.clientId,
      location: location ?? this.location,
      streetAddress: streetAddress ?? this.streetAddress,
      region: region ?? this.region,
      postalCode: postalCode ?? this.postalCode,
      pricingModel: pricingModel ?? this.pricingModel,
      isCompleted: isCompleted ?? this.isCompleted,
      completionDate: completionDate ?? this.completionDate,
      isInternal: isInternal ?? this.isInternal,
      billedHourlyRate: billedHourlyRate ?? this.billedHourlyRate,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      expenseMarkupPercentage: expenseMarkupPercentage ?? this.expenseMarkupPercentage,
      taxRate: taxRate ?? this.taxRate,
      parentProjectId: parentProjectId ?? this.parentProjectId,
    );
  }

  @override
  String toString() {
    return 'Project(id: $id, name: $projectName, clientId: $clientId, pricingModel: $pricingModel, fixedPrice: $fixedPrice, taxRate: $taxRate)';
  }
}

class Employee {
  final int? id;
  final String? employeeNumber;
  final String name;
  final int? titleId;
  final double? hourlyRate;
  final bool isDeleted;

  Employee({
    this.id,
    this.employeeNumber,
    required this.name,
    this.titleId,
    this.hourlyRate,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_number': employeeNumber,
      'name': name,
      'title_id': titleId,
      'hourly_rate': hourlyRate,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      employeeNumber: map['employee_number'],
      name: map['name'],
      titleId: map['title_id'],
      hourlyRate: (map['hourly_rate'] as num?)?.toDouble(),
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Employee copyWith({
    int? id,
    String? employeeNumber,
    String? name,
    int? titleId,
    double? hourlyRate,
    bool? isDeleted,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      name: name ?? this.name,
      titleId: titleId ?? this.titleId,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class WorkerPayment {
  final int? id;
  final int employeeId;
  final DateTime paymentDate;
  final double amount;
  final String? note;
  final DateTime createdAt;

  WorkerPayment({
    this.id,
    required this.employeeId,
    required this.paymentDate,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'payment_date': paymentDate.toIso8601String(),
    'amount': amount,
    'note': note,
    'created_at': createdAt.toIso8601String(),
  };

  factory WorkerPayment.fromMap(Map<String, dynamic> map) => WorkerPayment(
    id: map['id'],
    employeeId: map['employee_id'],
    paymentDate: DateTime.parse(map['payment_date']),
    amount: (map['amount'] as num).toDouble(),
    note: map['note'],
    createdAt: DateTime.parse(map['created_at']),
  );

  WorkerPayment copyWith({
    int? id,
    int? employeeId,
    DateTime? paymentDate,
    double? amount,
    String? note,
    DateTime? createdAt,
  }) {
    return WorkerPayment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
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

  }
      );

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
  final double? hourlyRate;
  final bool isPaused;
  final DateTime? pauseStartTime;
  final bool isDeleted;
  final String? workDetails;
  final int? costCodeId;
  final bool isBilled;
  final int? invoiceId;

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
    this.hourlyRate,
    this.costCodeId,
    this.isBilled = false,
    this.invoiceId,
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
      hourlyRate: (map['hourly_rate'] as num?)?.toDouble(),
      costCodeId: map['cost_code_id'],
      isBilled: (map['is_billed'] as int? ?? 0) == 1,
      invoiceId: map['invoice_id'] as int?,
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
      'hourly_rate': hourlyRate,
      'cost_code_id': costCodeId,
      'is_billed': isBilled ? 1 : 0,
      'invoice_id': invoiceId,
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
    double? hourlyRate,
    bool? isPaused,
    DateTime? pauseStartTime,
    bool? isDeleted,
    String? workDetails,
    int? costCodeId,
    bool? isBilled,
    int? invoiceId,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      employeeId: employeeId ?? this.employeeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      finalBilledDurationSeconds: finalBilledDurationSeconds ?? this.finalBilledDurationSeconds,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isPaused: isPaused ?? this.isPaused,
      pauseStartTime: pauseStartTime ?? this.pauseStartTime,
      isDeleted: isDeleted ?? this.isDeleted,
      workDetails: workDetails ?? this.workDetails,
      costCodeId: costCodeId ?? this.costCodeId,
      isBilled: isBilled ?? this.isBilled,
      invoiceId: invoiceId ?? this.invoiceId,
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
  final int? costCodeId;
  final bool isBilled;
  final int? invoiceId;

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
    this.costCodeId,
    this.isBilled = false,
    this.invoiceId,
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
      'cost_code_id': costCodeId,
      'is_billed': isBilled ? 1 : 0,
      'invoice_id': invoiceId,
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
      costCodeId: map['cost_code_id'],
      isBilled: (map['is_billed'] as int? ?? 0) == 1,
      invoiceId: map['invoice_id'] as int?,
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
    int? costCodeId,
    bool? isBilled,
    int? invoiceId,
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
      costCodeId: costCodeId ?? this.costCodeId,
      isBilled: isBilled ?? this.isBilled,
      invoiceId: invoiceId ?? this.invoiceId,
    );
  }
}

class CostCode {
  final int? id;
  final String name;
  final bool isBillable;

  CostCode({
    this.id,
    required this.name,
    this.isBillable = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_billable': isBillable ? 1 : 0,
    };
  }

  factory CostCode.fromMap(Map<String, dynamic> map) {
    return CostCode(
      id: map['id'],
      name: map['name'],
      isBillable: (map['is_billable'] as int? ?? 0) == 1,
    );
  }

  CostCode copyWith({
    int? id,
    String? name,
    bool? isBillable,
  }) {
    return CostCode(
      id: id ?? this.id,
      name: name ?? this.name,
      isBillable: isBillable ?? this.isBillable,
    );
  }

  @override
  String toString() {
    return 'CostCode(id: $id, name: $name, isBillable: $isBillable)';
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


// For the main dashboard screen
enum RecordType { time, expense, payment }

class AllRecordViewModel {
  final int id;
  final RecordType type;
  final DateTime date;
  final String description;
  final double value;
  final String categoryOrProject;
  final int? employeeId;
  final int? costCodeId;
  final String? costCodeName;

  AllRecordViewModel({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    required this.value,
    required this.categoryOrProject,
    this.employeeId,
    this.costCodeId,
    this.costCodeName,
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
  final double? fixedPrice; // ADDED: To carry the fixed price for the report
  final double totalHours;
  final double laborCost; // RENAMED: from totalLabourCost
  final double materialsCost; // RENAMED: from totalExpenses, will include markup
  final double totalCost; // ADDED: laborCost + materialsCost
  final double totalBilledValue;
  final String? clientName;
  final double profitLoss;

  const ProjectSummaryViewModel({
    required this.projectId,
    required this.projectName,
    required this.pricingModel,
    required this.billedRate,
    this.fixedPrice,
    required this.totalHours,
    required this.laborCost,
    required this.materialsCost,
    required this.totalCost,
    required this.totalBilledValue,
    required this.clientName,
    required this.profitLoss,
  });

  @override
  String toString() {
    // UPDATED: toString for better debugging
    return 'ProjectSummary(name: $projectName, Hours: ${totalHours.toStringAsFixed(2)}, Labor: ${laborCost.toStringAsFixed(2)}, Materials: ${materialsCost.toStringAsFixed(2)}, Total Cost: ${totalCost.toStringAsFixed(2)}, P/L: ${profitLoss.toStringAsFixed(2)})';
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
