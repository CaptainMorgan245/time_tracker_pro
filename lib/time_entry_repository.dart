// lib/time_entry_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class TimeEntryRepository {
  final _databaseHelper = DatabaseHelper();

  // start method: insertTimeEntry
  Future<int> insertTimeEntry(TimeEntry timeEntry) async {
    final db = await _databaseHelper.database;
    return await db.insert('time_entries', timeEntry.toMap());
  }
  // end method: insertTimeEntry

  // start method: getTimeEntries
  Future<List<TimeEntry>> getTimeEntries() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('time_entries');
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }
  // end method: getTimeEntries

  // start method: getTimeEntryById
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
  // end method: getTimeEntryById

  // start method: getActiveTimeEntries
  Future<List<TimeEntry>> getActiveTimeEntries() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'end_time IS NULL AND is_deleted = 0',
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }
  // end method: getActiveTimeEntries

  // start method: updateTimeEntry
  Future<int> updateTimeEntry(TimeEntry timeEntry) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'time_entries',
      timeEntry.toMap(),
      where: 'id = ?',
      whereArgs: [timeEntry.id],
    );
  }
  // end method: updateTimeEntry

  // start method: deleteTimeEntry
  Future<int> deleteTimeEntry(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'time_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteTimeEntry
}