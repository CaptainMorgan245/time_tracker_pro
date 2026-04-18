// lib/time_entry_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';

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

  Future<List<Map<String, dynamic>>> getCustomTimeEntriesReport(
      CustomReportSettings settings) async {
    final includes = settings.includes;
    final List<String> selectClauses = ['te.id'];

    if (includes['Date'] == true) {
      selectClauses.add("strftime('%Y-%m-%d', te.start_time) AS date");
    }
    if (includes['Employee'] == true) {
      selectClauses.add('e.name AS employee');
    }
    if (includes['Start Time'] == true) {
      selectClauses.add("strftime('%H:%M', te.start_time) AS start_time");
    }
    if (includes['End Time'] == true) {
      selectClauses.add("strftime('%H:%M', te.end_time) AS end_time");
    }
    if (includes['Hours'] == true) {
      selectClauses.add('ROUND(te.final_billed_duration_seconds / 3600.0, 2) AS hours');
    }
    if (includes['Cost Code'] == true) {
      selectClauses.add('COALESCE(cc.name, \'\') AS cost_code');
    }
    if (includes['Work Description'] == true) {
      selectClauses.add('COALESCE(te.work_details, \'\') AS work_description');
    }
    if (includes['Billed Status'] == true) {
      selectClauses.add("CASE WHEN te.is_billed = 1 THEN 'Billed' ELSE 'Unbilled' END AS billed_status");
    }

    final String select = selectClauses.join(', ');

    final List<String> whereClauses = ['te.is_deleted = 0', 'te.end_time IS NOT NULL'];
    final List<Variable> variables = [];

    if (settings.clientId != null) {
      whereClauses.add('p.client_id = ?');
      variables.add(Variable.withInt(settings.clientId!));
    }
    if (settings.projectId != null) {
      whereClauses.add('te.project_id = ?');
      variables.add(Variable.withInt(settings.projectId!));
    }
    if (settings.employeeId != null) {
      whereClauses.add('te.employee_id = ?');
      variables.add(Variable.withInt(settings.employeeId!));
    }
    if (settings.costCodeId != null) {
      whereClauses.add('te.cost_code_id = ?');
      variables.add(Variable.withInt(settings.costCodeId!));
    }
    if (settings.startDate != null) {
      whereClauses.add('te.start_time >= ?');
      variables.add(Variable.withString(settings.startDate!.toIso8601String()));
    }
    if (settings.endDate != null) {
      whereClauses.add('te.start_time < ?');
      variables.add(Variable.withString(
          settings.endDate!.add(const Duration(days: 1)).toIso8601String()));
    }

    final String where = whereClauses.join(' AND ');

    final rows = await _db.customSelect('''
      SELECT $select
      FROM time_entries te
      LEFT JOIN employees e ON te.employee_id = e.id
      LEFT JOIN projects p ON te.project_id = p.id
      LEFT JOIN cost_codes cc ON te.cost_code_id = cc.id
      WHERE $where
      ORDER BY te.start_time DESC
    ''', variables: variables).get();

    // Strip the internal id column from the returned maps
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r.data);
      map.remove('id');
      return map;
    }).toList();
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
