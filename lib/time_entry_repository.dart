// lib/time_entry_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class TimeEntryRepository {
  Future<Database> get _db async => await DatabaseHelper().database;

  Future<int> insertTimeEntry(TimeEntry entry) async {
    final db = await _db;
    return await db.insert('time_entries', entry.toMap());
  }

  Future<TimeEntry?> getTimeEntryById(int id) async {
    final db = await _db;
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

  Future<List<TimeEntry>> getActiveTimeEntries() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'end_time IS NULL',
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<List<TimeEntry>> getAllTimeEntries() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      orderBy: 'start_time DESC',
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<List<TimeEntry>> getRecentTimeEntries({int limit = 10}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      orderBy: 'start_time DESC',
      limit: limit,
      where: 'end_time IS NOT NULL',
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    final db = await _db;
    await db.update(
      'time_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteTimeEntry(int id) async {
    final db = await _db;
    await db.delete(
      'time_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}