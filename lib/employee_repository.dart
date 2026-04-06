// lib/employee_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';

class EmployeeRepository {
  final _db = AppDatabase.instance;

  Future<int> insertEmployee(Employee employee) async {
    int newEmployeeId = -1;

    await _db.transaction(() async {
      final settingsRow = await _db.customSelect(
        'SELECT next_employee_number, employee_number_prefix FROM settings WHERE id = 1 LIMIT 1',
      ).getSingle();

      final int nextNumber = settingsRow.data['next_employee_number'] as int;
      final String prefix = settingsRow.data['employee_number_prefix'] as String? ?? '';

      String employeeNumberToSave = employee.employeeNumber ?? '';
      if (employeeNumberToSave.isEmpty) {
        employeeNumberToSave = '$prefix$nextNumber';
      }

      newEmployeeId = await _db.customInsert(
        'INSERT OR REPLACE INTO employees (employee_number, name, title_id, hourly_rate, is_deleted) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable(employeeNumberToSave),
          Variable.withString(employee.name),
          Variable(employee.titleId),
          Variable(employee.hourlyRate),
          Variable.withInt(employee.isDeleted ? 1 : 0),
        ],
      );

      await _db.customUpdate(
        'UPDATE settings SET next_employee_number = ? WHERE id = 1',
        variables: [Variable.withInt(nextNumber + 1)],
        updates: {},
      );
    });

    _db.notifyDatabaseChanged();
    return newEmployeeId;
  }

  Future<List<EmployeeSummaryViewModel>> fetchEmployeeSummaries() async {
    final rows = await _db.customSelect('''
    SELECT 
      e.name AS employeeName, 
      e.employee_number AS employeeNumber, 
      r.name AS roleTitle,
      COUNT(DISTINCT t.project_id) AS projectsCount,
      SUM(t.final_billed_duration_seconds / 3600.0) AS totalHours,
      SUM((t.final_billed_duration_seconds / 3600.0) * IFNULL(e.hourly_rate, 0)) AS totalBilledValue
    FROM employees e
    JOIN time_entries t ON e.id = t.employee_id
    JOIN projects p ON t.project_id = p.id
    JOIN roles r ON e.title_id = r.id
    WHERE e.is_deleted = 0
    GROUP BY e.id;
  ''').get();

    return rows.map((r) {
      final map = r.data;
      return EmployeeSummaryViewModel(
        employeeName: map['employeeName'],
        employeeNumber: map['employeeNumber'],
        roleTitle: map['roleTitle'],
        projectsCount: map['projectsCount'],
        totalHours: map['totalHours']?.toDouble() ?? 0.0,
        totalBilledValue: map['totalBilledValue']?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<List<Employee>> getEmployees() async {
    final rows = await _db.customSelect('SELECT * FROM employees WHERE is_deleted = 0').get();
    return rows.map((r) => Employee.fromMap(r.data)).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM employees WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first.data);
  }

  Future<List<Map<String, dynamic>>> getCustomPersonnelReport(CustomReportSettings settings) async {
    List<String> whereConditions = ['e.is_deleted = 0'];
    List<Variable> vars = [];

    if (settings.employeeId != null) {
      whereConditions.add('e.id = ?');
      vars.add(Variable.withInt(settings.employeeId!));
    }

    String whereClause = whereConditions.join(' AND ');

    String dateFilter = '';
    if (settings.startDate != null) {
      dateFilter += ' AND te.start_time >= ?';
      vars.add(Variable.withString(settings.startDate!.toIso8601String()));
    }
    if (settings.endDate != null) {
      dateFilter += ' AND te.start_time <= ?';
      vars.add(Variable.withString(settings.endDate!.toIso8601String()));
    }

    List<String> selectFields = ['e.name AS employee'];
    if (settings.includes['Role & Status'] == true) selectFields.add('r.name AS role');
    if (settings.includes['Projects Assigned'] == true) selectFields.add('COUNT(DISTINCT te.project_id) AS projects_count');
    if (settings.includes['Total Hours Logged'] == true) selectFields.add('SUM(te.final_billed_duration_seconds / 3600.0) AS total_hours');
    if (settings.includes['Total Billed Value'] == true) selectFields.add('SUM((te.final_billed_duration_seconds / 3600.0) * IFNULL(e.hourly_rate, 0)) AS billed_value');

    final query = '''
    SELECT ${selectFields.join(', ')}
    FROM employees e
    LEFT JOIN roles r ON e.title_id = r.id
    LEFT JOIN time_entries te ON e.id = te.employee_id $dateFilter
    LEFT JOIN projects p ON te.project_id = p.id
    WHERE $whereClause
    GROUP BY e.id
    ORDER BY e.name
  ''';

    final rows = await _db.customSelect(query, variables: vars).get();
    return rows.map((r) => r.data).toList();
  }

  Future<int> updateEmployee(Employee employee) async {
    final result = await _db.customUpdate(
      'UPDATE employees SET employee_number = ?, name = ?, title_id = ?, hourly_rate = ?, is_deleted = ? WHERE id = ?',
      variables: [
        Variable(employee.employeeNumber),
        Variable.withString(employee.name),
        Variable(employee.titleId),
        Variable(employee.hourlyRate),
        Variable.withInt(employee.isDeleted ? 1 : 0),
        Variable.withInt(employee.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteEmployee(int id) async {
    final result = await _db.customUpdate(
      'UPDATE employees SET is_deleted = 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
