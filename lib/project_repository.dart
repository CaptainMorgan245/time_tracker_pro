// lib/project_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart'; // This file now only exports DatabaseHelperV2
import 'package:time_tracker_pro/models.dart';

class ProjectRepository {
  // THE FIX: This now correctly points to the one and only active database helper class.
  final _databaseHelper = DatabaseHelperV2.instance;

  Future<int> insertProject(Project project) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('projects', project.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _databaseHelper.notifyDatabaseChanged(); // This call will now succeed.
    return id;
  }

  Future<List<Project>> getProjects() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('projects');
    return List.generate(maps.length, (i) {
      return Project.fromMap(maps[i]);
    });
  }

  Future<Project?> getProjectById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Project.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateProject(Project project) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
    _databaseHelper.notifyDatabaseChanged(); // This call will now succeed.
    return result;
  }

  Future<int> deleteProject(int id) async {
    final db = await _databaseHelper.database;
    // Also delete associated time and cost records when deleting
    await db.delete('time_records', where: 'projectId = ?', whereArgs: [id]);
    await db.delete('job_materials', where: 'projectId = ?', whereArgs: [id]);
    final result = await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    _databaseHelper.notifyDatabaseChanged(); // This call will now succeed.
    return result;
  }

  Future<bool> hasAssociatedRecords(int projectId) async {
    final db = await _databaseHelper.database;
    final timeRecordsCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM time_records WHERE projectId = ?', [projectId]));
    final costRecordsCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM job_materials WHERE projectId = ?', [projectId]));

    return (timeRecordsCount ?? 0) > 0 || (costRecordsCount ?? 0) > 0;
  }

  Future<int> markAsCompleted(int id) async {
    Database db = await _databaseHelper.database;
    final result = await db.update(
      'projects',
      {'isCompleted': 1}, // 1 for true in SQLite
      where: 'id = ?',
      whereArgs: [id],
    );
    _databaseHelper.notifyDatabaseChanged(); // This call will now succeed.
    return result;
  }
}
