// lib/material_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class MaterialRepository {
  final _databaseHelper = DatabaseHelper();

  // start method: insertMaterial
  Future<int> insertMaterial(Material material) async {
    final db = await _databaseHelper.database;
    return await db.insert('materials', material.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // end method: insertMaterial

  // start method: getMaterials
  Future<List<Material>> getMaterials() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('materials', where: 'is_deleted = 0');
    return List.generate(maps.length, (i) {
      return Material.fromMap(maps[i]);
    });
  }
  // end method: getMaterials

  // start method: getMaterialByProjectId
  Future<List<Material>> getMaterialByProjectId(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'materials',
      where: 'project_id = ? AND is_deleted = 0',
      whereArgs: [projectId],
    );
    return List.generate(maps.length, (i) {
      return Material.fromMap(maps[i]);
    });
  }
  // end method: getMaterialByProjectId

  // start method: getMaterialById
  Future<Material?> getMaterialById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Material.fromMap(maps.first);
    }
    return null;
  }
  // end method: getMaterialById

  // start method: updateMaterial
  Future<int> updateMaterial(Material material) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'materials',
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }
  // end method: updateMaterial

  // start method: deleteMaterial
  Future<int> deleteMaterial(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteMaterial
}