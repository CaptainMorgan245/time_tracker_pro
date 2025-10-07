// lib/employee_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/settings_model.dart';

class EmployeeRepository {
  // Use the V2 instance to get access to the notifier.
  final _databaseHelper = DatabaseHelperV2.instance;
  final _settingsService = SettingsService.instance;

  Future<int> insertEmployee(Employee employee) async {
    final db = await _databaseHelper.database;
    int id;

    if (employee.employeeNumber == null || employee.employeeNumber!.isEmpty) {
      // This logic is complex, so we ensure the notification happens after any insert.
      SettingsModel settings = await _settingsService.loadSettings();

      final newEmployeeNumber = '${settings.employeeNumberPrefix ?? ''}${settings.nextEmployeeNumber ?? 1}';

      final newEmployee = employee.copyWith(
        employeeNumber: newEmployeeNumber,
      );

      // FIX 1: Fix null safety error by providing a default value of 0 before adding 1.
      final updatedSettings = settings.copyWith(
        nextEmployeeNumber: (settings.nextEmployeeNumber ?? 0) + 1,
      );
      await _settingsService.saveSettings(updatedSettings);

      id = await db.insert('employees', newEmployee.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      id = await db.insert('employees', employee.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // FIX 2: Call the new PUBLIC method to notify listeners.
    _databaseHelper.notifyDatabaseChanged();
    return id;
  }

  Future<List<Employee>> getEmployees() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('employees', where: 'is_deleted = 0');
    return List.generate(maps.length, (i) {
      return Employee.fromMap(maps[i]);
    });
  }

  Future<Employee?> getEmployeeById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Employee.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateEmployee(Employee employee) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
    // FIX 3: Call the new PUBLIC method to notify listeners.
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteEmployee(int id) async {
    final db = await _databaseHelper.database;
    // Instead of a hard delete, we'll mark the employee as deleted.
    // This preserves historical data integrity.
    final updatedEmployee = {'is_deleted': 1};
    final result = await db.update(
      'employees',
      updatedEmployee,
      where: 'id = ?',
      whereArgs: [id],
    );

    // FIX 4: Call the new PUBLIC method to notify listeners.
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }
}
