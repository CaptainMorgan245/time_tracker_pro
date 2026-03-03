// lib/cost_code_repository.dart

import 'package:sqflite/sqflite.dart';
import 'models.dart';

class CostCodeRepository {
  final Database db;

  CostCodeRepository(this.db);

  Future<List<CostCode>> getAllCostCodes() async {
    final List<Map<String, dynamic>> maps = await db.query('cost_codes');
    return List.generate(maps.length, (i) => CostCode.fromMap(maps[i]));
  }

  Future<CostCode?> getCostCodeById(int id) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'cost_codes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CostCode.fromMap(maps.first);
  }

  Future<int> insertCostCode(CostCode costCode) async {
    return await db.insert('cost_codes', costCode.toMap());
  }

  Future<int> updateCostCode(CostCode costCode) async {
    return await db.update(
      'cost_codes',
      costCode.toMap(),
      where: 'id = ?',
      whereArgs: [costCode.id],
    );
  }

  Future<int> deleteCostCode(int id) async {
    return await db.delete(
      'cost_codes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
