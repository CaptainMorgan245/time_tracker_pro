// lib/job_materials_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class JobMaterialsRepository {
  final _databaseHelper = DatabaseHelper.instance;
  final String _tableName = 'materials'; // Confirmed table name from database_helper

  // start method: insertJobMaterial
  Future<int> insertJobMaterial(JobMaterials material) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      _tableName,
      material.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // end method: insertJobMaterial

  // start method: getJobMaterials
  // Updated to accept an optional 'limit' for fetching recent records
  Future<List<JobMaterials>> getJobMaterials({int? limit}) async {
    final db = await _databaseHelper.database;

    // FIX: Pass the limit directly as an int?, removing unnecessary String conversion
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'id DESC', // Assumes higher ID means more recent
      limit: limit, // Now passing int? directly
    );

    return List.generate(maps.length, (i) {
      return JobMaterials.fromMap(maps[i]);
    });
  }
  // end method: getJobMaterials

  // start method: getJobMaterialsByProjectId
  Future<List<JobMaterials>> getJobMaterialsByProjectId(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'purchase_date DESC',
    );
    return List.generate(maps.length, (i) {
      return JobMaterials.fromMap(maps[i]);
    });
  }
  // end method: getJobMaterialsByProjectId

  // start method: updateJobMaterial
  Future<int> updateJobMaterial(JobMaterials material) async {
    final db = await _databaseHelper.database;
    return await db.update(
      _tableName,
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }
  // end method: updateJobMaterial

  // start method: deleteJobMaterial
  Future<int> deleteJobMaterial(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteJobMaterial
}
