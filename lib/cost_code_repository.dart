// lib/cost_code_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class CostCodeRepository {
  final _db = AppDatabase.instance;

  Future<List<CostCode>> getAllCostCodes() async {
    final rows = await _db.customSelect('SELECT * FROM cost_codes').get();
    return rows.map((r) => CostCode.fromMap(r.data)).toList();
  }

  Future<CostCode?> getCostCodeById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM cost_codes WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return CostCode.fromMap(rows.first.data);
  }

  Future<int> insertCostCode(CostCode costCode) async {
    final id = await _db.customInsert(
      'INSERT INTO cost_codes (name, is_billable) VALUES (?, ?)',
      variables: [
        Variable.withString(costCode.name),
        Variable.withInt(costCode.isBillable ? 1 : 0),
      ],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<int> updateCostCode(CostCode costCode) async {
    final result = await _db.customUpdate(
      'UPDATE cost_codes SET name = ?, is_billable = ? WHERE id = ?',
      variables: [
        Variable.withString(costCode.name),
        Variable.withInt(costCode.isBillable ? 1 : 0),
        Variable.withInt(costCode.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteCostCode(int id) async {
    final result = await _db.customUpdate(
      'DELETE FROM cost_codes WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
