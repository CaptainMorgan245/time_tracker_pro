import 'package:drift/drift.dart';

// Settings table
@DataClassName('DbSetting')
class Settings extends Table {
  IntColumn get id => integer()();
  TextColumn get employeeNumberPrefix => text().nullable()();
  IntColumn get nextEmployeeNumber => integer().nullable()();
  TextColumn get vehicleDesignations => text().nullable()();
  TextColumn get vendors => text().nullable()();
  RealColumn get companyHourlyRate => real().nullable()();
  RealColumn get burdenRate => real().nullable()();
  IntColumn get timeRoundingInterval => integer().nullable()();
  IntColumn get autoBackupReminderFrequency => integer().nullable()();
  IntColumn get appRunsSinceBackup => integer().nullable()();
  TextColumn get measurementSystem => text().nullable()();
  IntColumn get defaultReportMonths => integer().nullable()();
  RealColumn get expenseMarkupPercentage => real().nullable()();
  IntColumn get setupCompleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Clients table
@DataClassName('DbClient')
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get isActive => integer().withDefault(const Constant(1))();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
}

// Projects table
@DataClassName('DbProject')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectName => text()();
  IntColumn get clientId => integer().references(Clients, #id)();
  TextColumn get city => text().nullable()();
  TextColumn get streetAddress => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get pricingModel => text().withDefault(const Constant('hourly'))();
  IntColumn get isCompleted => integer().withDefault(const Constant(0))();
  TextColumn get completionDate => text().nullable()();
  IntColumn get isInternal => integer().withDefault(const Constant(0))();
  RealColumn get billedHourlyRate => real().nullable()();
  RealColumn get projectPrice => real().nullable()();
  RealColumn get expenseMarkupPercentage => real().withDefault(const Constant(15.0))();
  RealColumn get taxRate => real().withDefault(const Constant(5.0))();
  IntColumn get parentProjectId => integer().nullable().references(Projects, #id)();
}

// Roles table
@DataClassName('DbRole')
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  RealColumn get standardRate => real().withDefault(const Constant(0.0))();
}

// Employees table
@DataClassName('DbEmployee')
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get employeeNumber => text().unique().nullable()();
  TextColumn get name => text()();
  IntColumn get titleId => integer().nullable().references(Roles, #id)();
  RealColumn get hourlyRate => real().nullable()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();
}

// Cost codes table
@DataClassName('DbCostCode')
class CostCodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get isBillable => integer().withDefault(const Constant(0))();
}

// Expense categories table
@DataClassName('DbExpenseCategory')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

// Invoices table
@DataClassName('DbInvoice')
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get invoiceDate => text()();
  IntColumn get clientId => integer().references(Clients, #id)();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get projectAddress => text().nullable()();
  RealColumn get labourSubtotal => real().withDefault(const Constant(0))();
  RealColumn get materialsSubtotal => real().withDefault(const Constant(0))();
  RealColumn get materialsPickupCost => real().withDefault(const Constant(0))();
  RealColumn get otherCosts => real().withDefault(const Constant(0))();
  TextColumn get otherCostsDescription => text().nullable()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  TextColumn get discountDescription => text().nullable()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  TextColumn get tax1Name => text().nullable()();
  RealColumn get tax1Rate => real().nullable()();
  RealColumn get tax1Amount => real().withDefault(const Constant(0))();
  TextColumn get tax1RegistrationNumber => text().nullable()();
  TextColumn get tax2Name => text().nullable()();
  RealColumn get tax2Rate => real().nullable()();
  RealColumn get tax2Amount => real().withDefault(const Constant(0))();
  TextColumn get tax2RegistrationNumber => text().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  TextColumn get terms => text().withDefault(const Constant('Payable on Receipt'))();
  TextColumn get poNumber => text().nullable()();
  IntColumn get isPaid => integer().withDefault(const Constant(0))();
  RealColumn get amountPaid => real().nullable()();
  TextColumn get paymentDate => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();
  TextColumn get deletedReasonCode => text().nullable()();
  TextColumn get deletedDate => text().nullable()();
  TextColumn get deletedNotes => text().nullable()();
  IntColumn get supersededByInvoiceId => integer().nullable().references(Invoices, #id)();
  TextColumn get notes => text().nullable()();
  TextColumn get internalNotes => text().nullable()();
  TextColumn get workDescription => text().nullable()();
  IntColumn get isSent => integer().withDefault(const Constant(0))();
  TextColumn get invoiceType => text().withDefault(const Constant('progress'))();
}

// Time entries table
@DataClassName('DbTimeEntry')
class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get employeeId => integer().nullable().references(Employees, #id)();
  TextColumn get startTime => text()();
  TextColumn get endTime => text().nullable()();
  RealColumn get pausedDuration => real().withDefault(const Constant(0.0))();
  RealColumn get finalBilledDurationSeconds => real().nullable()();
  RealColumn get hourlyRate => real().nullable()();
  IntColumn get isPaused => integer().withDefault(const Constant(0))();
  TextColumn get pauseStartTime => text().nullable()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();
  TextColumn get workDetails => text().nullable()();
  IntColumn get costCodeId => integer().nullable().references(CostCodes, #id)();
  IntColumn get isBilled => integer().withDefault(const Constant(0))();
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
}

// Materials table
@DataClassName('DbMaterial')
class Materials extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get itemName => text()();
  RealColumn get cost => real()();
  TextColumn get purchaseDate => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();
  TextColumn get expenseCategory => text().nullable()();
  TextColumn get unit => text().nullable()();
  RealColumn get quantity => real().nullable()();
  RealColumn get baseQuantity => real().nullable()();
  RealColumn get odometerReading => real().nullable()();
  IntColumn get isCompanyExpense => integer().withDefault(const Constant(0))();
  TextColumn get vehicleDesignation => text().nullable()();
  TextColumn get vendorOrSubtrade => text().nullable()();
  IntColumn get costCodeId => integer().nullable().references(CostCodes, #id)();
  IntColumn get isBilled => integer().withDefault(const Constant(0))();
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
}

// Company settings table (singleton row, id always = 1)
@DataClassName('DbCompanySetting')
class CompanySettingsTable extends Table {
  @override
  String get tableName => 'company_settings';

  IntColumn get id => integer()();
  TextColumn get companyName => text().nullable()();
  TextColumn get companyAddress => text().nullable()();
  TextColumn get companyCity => text().nullable()();
  TextColumn get companyProvince => text().nullable()();
  TextColumn get companyPostalCode => text().nullable()();
  TextColumn get companyPhone => text().nullable()();
  TextColumn get companyEmail => text().nullable()();
  TextColumn get defaultTax1Name => text().withDefault(const Constant('GST'))();
  RealColumn get defaultTax1Rate => real().withDefault(const Constant(0.05))();
  TextColumn get defaultTax1RegistrationNumber => text().nullable()();
  TextColumn get defaultTax2Name => text().nullable()();
  RealColumn get defaultTax2Rate => real().nullable()();
  TextColumn get defaultTax2RegistrationNumber => text().nullable()();
  TextColumn get defaultTerms => text().withDefault(const Constant('Payable on Receipt'))();
  RealColumn get taxRate => real().withDefault(const Constant(5.0))();

  TextColumn get postalCodeLabel => text().withDefault(const Constant('Postal Code'))();
  TextColumn get regionLabel => text().withDefault(const Constant('Province'))();
  TextColumn get country => text().withDefault(const Constant('Canada'))();

  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();
  IntColumn get invoiceStartingNumber => integer().withDefault(const Constant(1))();
  TextColumn get paymentEtransferEmail => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Worker payments table
@DataClassName('DbWorkerPayment')
class WorkerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer().references(Employees, #id)();
  TextColumn get paymentDate => text()();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()();
}
