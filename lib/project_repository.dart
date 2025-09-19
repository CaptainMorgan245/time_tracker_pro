// lib/project_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class ProjectRepository {
  final _databaseHelper = DatabaseHelper();

  // start method: insertProject
  Future<int> insertProject(Project project) async {
    final db = await _databaseHelper.database;
    return await db.insert('projects', project.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // end method: insertProject

  // start method: getProjects
  Future<List<Project>> getProjects() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('projects');
    return List.generate(maps.length, (i) {
      return Project.fromMap(maps[i]);
    });
  }
  // end method: getProjects

  // start method: getProjectById
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
  // end method: getProjectById

  // start method: updateProject
  Future<int> updateProject(Project project) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }
  // end method: updateProject

  // start method: deleteProject
  Future<int> deleteProject(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteProject
}