// lib/role_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class RoleRepository {
  final _databaseHelper = DatabaseHelper.instance;

  // start method: insertRole
  Future<int> insertRole(Role role) async {
    final db = await _databaseHelper.database;
    return await db.insert('roles', role.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // end method: insertRole

  // start method: getRoles
  Future<List<Role>> getRoles() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('roles');
    return List.generate(maps.length, (i) {
      return Role.fromMap(maps[i]);
    });
  }
  // end method: getRoles

  // start method: getRoleById
  Future<Role?> getRoleById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'roles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Role.fromMap(maps.first);
    }
    return null;
  }
  // end method: getRoleById

  // start method: updateRole
  Future<int> updateRole(Role role) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'roles',
      role.toMap(),
      where: 'id = ?',
      whereArgs: [role.id],
    );
  }
  // end method: updateRole

  // start method: deleteRole
  Future<int> deleteRole(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'roles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteRole
}