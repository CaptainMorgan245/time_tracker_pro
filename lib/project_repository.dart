// lib/project_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class ProjectRepository {
  final _databaseHelper = DatabaseHelperV2.instance;

  // HELPER FUNCTION: To get the company's default hourly rate from settings.
  Future<double> _getCompanyRate(Database db) async {
    final List<Map<String, dynamic>> settings = await db.query('settings', limit: 1);
    if (settings.isNotEmpty) {
      // Safely cast the number and provide a fallback of 0.0.
      return (settings.first['company_hourly_rate'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  Future<int> insertProject(Project project) async {
    final db = await _databaseHelper.database;
    Map<String, dynamic> projectMap = project.toMap();

    // YOUR LOGIC: If the project is hourly and no valid rate is provided,
    // fetch the company's default rate and insert it into the table.
    if (projectMap['pricing_model'] == 'hourly' && ((projectMap['billed_hourly_rate'] as num?) ?? 0.0) <= 0.0) {
      final companyRate = await _getCompanyRate(db);
      projectMap['billed_hourly_rate'] = companyRate;
    }

    final id = await db.insert('projects', projectMap, conflictAlgorithm: ConflictAlgorithm.replace);
    _databaseHelper.notifyDatabaseChanged();
    return id;
  }

  Future<int> updateProject(Project project) async {
    final db = await _databaseHelper.database;
    Map<String, dynamic> projectMap = project.toMap();

    // YOUR LOGIC: Apply the same rule when updating a project.
    if (projectMap['pricing_model'] == 'hourly' && ((projectMap['billed_hourly_rate'] as num?) ?? 0.0) <= 0.0) {
      final companyRate = await _getCompanyRate(db);
      projectMap['billed_hourly_rate'] = companyRate;
    }

    final result = await db.update(
      'projects',
      projectMap,
      where: 'id = ?',
      whereArgs: [project.id],
    );
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }

  // --- NO CHANGES TO THE METHODS BELOW ---

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

  Future<int> deleteProject(int id) async {
    final db = await _databaseHelper.database;
    // Your original file had 'time_records' and 'job_materials', but the schema uses 'time_entries' and 'materials'.
    // I will use the correct table names from the schema to avoid errors.
    await db.delete('time_entries', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('materials', where: 'project_id = ?', whereArgs: [id]);
    final result = await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }

  Future<bool> hasAssociatedRecords(int projectId) async {
    final db = await _databaseHelper.database;
    // Using correct table names from schema
    final timeRecordsCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM time_entries WHERE project_id = ?', [projectId]));
    final costRecordsCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM materials WHERE project_id = ?', [projectId]));

    return (timeRecordsCount ?? 0) > 0 || (costRecordsCount ?? 0) > 0;
  }

  Future<int> markAsCompleted(int id) async {
    Database db = await _databaseHelper.database;
    final result = await db.update(
      'projects',
      // Correcting the key to match the database schema ('is_completed')
      {'is_completed': 1}, // 1 for true in SQLite
      where: 'id = ?',
      whereArgs: [id],
    );
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }
}
