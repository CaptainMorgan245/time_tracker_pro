// lib/role_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class RoleRepository {
  final _db = AppDatabase.instance;

  Future<int> insertRole(Role role) async {
    final id = await _db.customInsert(
      'INSERT OR REPLACE INTO roles (name, standard_rate) VALUES (?, ?)',
      variables: [
        Variable.withString(role.name),
        Variable.withReal(role.standardRate),
      ],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<List<Role>> getRoles() async {
    final rows = await _db.customSelect('SELECT * FROM roles').get();
    return rows.map((r) => Role.fromMap(r.data)).toList();
  }

  Future<Role?> getRoleById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM roles WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Role.fromMap(rows.first.data);
  }

  Future<int> updateRole(Role role) async {
    final result = await _db.customUpdate(
      'UPDATE roles SET name = ?, standard_rate = ? WHERE id = ?',
      variables: [
        Variable.withString(role.name),
        Variable.withReal(role.standardRate),
        Variable.withInt(role.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteRole(int id) async {
    final result = await _db.customUpdate(
      'DELETE FROM roles WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
