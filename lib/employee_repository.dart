// lib/employee_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/settings_model.dart';

class EmployeeRepository {
  final _databaseHelper = DatabaseHelper();
  final _settingsService = SettingsService();

  Future<int> insertEmployee(Employee employee) async {
    final db = await _databaseHelper.database;

    if (employee.employeeNumber == null || employee.employeeNumber!.isEmpty) {
      SettingsModel settings = await _settingsService.loadSettings() ?? SettingsModel();

      final newEmployeeNumber = '${settings.employeeNumberPrefix ?? ''}${settings.nextEmployeeNumber ?? 1}';

      final newEmployee = employee.copyWith(
        employeeNumber: newEmployeeNumber,
      );

      final updatedSettings = settings.copyWith(
        nextEmployeeNumber: (settings.nextEmployeeNumber ?? 0) + 1,
      );
      await _settingsService.saveSettings(updatedSettings);

      return await db.insert('employees', newEmployee.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      return await db.insert('employees', employee.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
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
    return await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}