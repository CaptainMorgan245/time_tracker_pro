// lib/time_entry_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class TimeEntryRepository {
  final _db = AppDatabase.instance;

  Future<int> insertTimeEntry(TimeEntry timeEntry) async {
    final id = await _db.customInsert(
      '''INSERT INTO time_entries (
        project_id, employee_id, start_time, end_time, paused_duration,
        final_billed_duration_seconds, hourly_rate, is_paused, pause_start_time,
        is_deleted, work_details, cost_code_id, is_billed, invoice_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withInt(timeEntry.projectId),
        Variable(timeEntry.employeeId),
        Variable.withString(timeEntry.startTime.toIso8601String()),
        Variable(timeEntry.endTime?.toIso8601String()),
        Variable.withReal(timeEntry.pausedDuration.inMicroseconds / 1000000.0),
        Variable(timeEntry.finalBilledDurationSeconds),
        Variable(timeEntry.hourlyRate),
        Variable.withInt(timeEntry.isPaused ? 1 : 0),
        Variable(timeEntry.pauseStartTime?.toIso8601String()),
        Variable.withInt(timeEntry.isDeleted ? 1 : 0),
        Variable(timeEntry.workDetails),
        Variable(timeEntry.costCodeId),
        Variable.withInt(timeEntry.isBilled ? 1 : 0),
        Variable(timeEntry.invoiceId),
      ],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<int> updateTimeEntry(TimeEntry timeEntry) async {
    final result = await _db.customUpdate(
      '''UPDATE time_entries SET
        project_id = ?, employee_id = ?, start_time = ?, end_time = ?,
        paused_duration = ?, final_billed_duration_seconds = ?, hourly_rate = ?,
        is_paused = ?, pause_start_time = ?, is_deleted = ?, work_details = ?,
        cost_code_id = ?, is_billed = ?, invoice_id = ?
      WHERE id = ?''',
      variables: [
        Variable.withInt(timeEntry.projectId),
        Variable(timeEntry.employeeId),
        Variable.withString(timeEntry.startTime.toIso8601String()),
        Variable(timeEntry.endTime?.toIso8601String()),
        Variable.withReal(timeEntry.pausedDuration.inMicroseconds / 1000000.0),
        Variable(timeEntry.finalBilledDurationSeconds),
        Variable(timeEntry.hourlyRate),
        Variable.withInt(timeEntry.isPaused ? 1 : 0),
        Variable(timeEntry.pauseStartTime?.toIso8601String()),
        Variable.withInt(timeEntry.isDeleted ? 1 : 0),
        Variable(timeEntry.workDetails),
        Variable(timeEntry.costCodeId),
        Variable.withInt(timeEntry.isBilled ? 1 : 0),
        Variable(timeEntry.invoiceId),
        Variable.withInt(timeEntry.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<List<TimeEntry>> getActiveTimeEntries() async {
    final rows = await _db.customSelect(
      'SELECT * FROM time_entries WHERE end_time IS NULL AND is_deleted = 0 ORDER BY start_time DESC',
    ).get();
    return rows.map((r) => TimeEntry.fromMap(r.data)).toList();
  }

  Future<TimeEntry?> getTimeEntryById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM time_entries WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return TimeEntry.fromMap(rows.first.data);
  }

  Future<List<TimeEntry>> getTimeEntriesForProject(int projectId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM time_entries WHERE project_id = ? AND is_deleted = 0 ORDER BY start_time DESC',
      variables: [Variable.withInt(projectId)],
    ).get();
    return rows.map((r) => TimeEntry.fromMap(r.data)).toList();
  }

  Future<int> deleteTimeEntry(int id) async {
    final result = await _db.customUpdate(
      'UPDATE time_entries SET is_deleted = 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
