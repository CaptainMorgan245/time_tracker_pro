// lib/time_entry_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/database_helper.dart';

class TimeEntryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertTimeEntry(TimeEntry entry) async {
    Database db = await _dbHelper.database;
    return await db.insert(
      'time_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TimeEntry?> getTimeEntryById(int id) async {
    Database db = await _dbHelper.database;
    List<Map<String, dynamic>> maps = await db.query(
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
    Database db = await _dbHelper.database;
    List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'end_time IS NULL AND is_paused = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<List<TimeEntry>> getRecentTimeEntries({int limit = 10}) async {
    Database db = await _dbHelper.database;
    List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<List<TimeEntry>> getAllTimeEntries() async {
    Database db = await _dbHelper.database;
    List<Map<String, dynamic>> maps = await db.query(
      'time_entries',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'start_time DESC',
    );
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    Database db = await _dbHelper.database;
    await db.update(
      'time_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteTimeEntry(int id) async {
    Database db = await _dbHelper.database;
    await db.delete(
      'time_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteTimeEntry(int id) async {
    Database db = await _dbHelper.database;
    await db.update(
      'time_entries',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}