// lib/time_entry_repository.dart

//import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class TimeEntryRepository {
  final _databaseHelper = DatabaseHelperV2.instance;

  Future<int> insertTimeEntry(TimeEntry timeEntry) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('time_entries', timeEntry.toMap());
    _databaseHelper.notifyDatabaseChanged();
    return id;
  }

  Future<int> updateTimeEntry(TimeEntry timeEntry) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'time_entries',
      timeEntry.toMap(),
      where: 'id = ?',
      whereArgs: [timeEntry.id],
    );
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }

  // CORRECTED: Method to get a list of all active (non-completed) time entries
  Future<List<TimeEntry>> getActiveTimeEntries() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'end_time IS NULL AND is_deleted = 0',
      orderBy: 'start_time DESC',
    );
    if (maps.isNotEmpty) {
      return List.generate(maps.length, (i) => TimeEntry.fromMap(maps[i]));
    }
    return []; // Return an empty list if none are found
  }

  // RESTORED: This method is needed by the dashboard's onTap for recent activities.
  Future<TimeEntry?> getTimeEntryById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TimeEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TimeEntry>> getTimeEntriesForProject(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'project_id = ? AND is_deleted = 0',
      whereArgs: [projectId],
      orderBy: 'start_time DESC',
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<int> deleteTimeEntry(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'time_entries',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _databaseHelper.notifyDatabaseChanged();
    return result;
  }
}
