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

  Future<List<Map<String, dynamic>>> getCustomProjectDetailReport(
      CustomReportSettings settings) async {
    final includes = settings.includes;

    // Labour (time entries) WHERE clauses
    final List<String> labourWhere = ['te.is_deleted = 0', 'te.end_time IS NOT NULL', '(te.cost_code_id IN (SELECT id FROM cost_codes WHERE is_billable = 1) OR te.cost_code_id IS NULL)'];
    final List<Variable> labourVars = [];

    // Material WHERE clauses
    final List<String> materialWhere = ['m.is_deleted = 0', 'm.is_company_expense = 0', '(m.cost_code_id IN (SELECT id FROM cost_codes WHERE is_billable = 1) OR m.cost_code_id IS NULL)'];
    final List<Variable> materialVars = [];

    if (settings.clientId != null) {
      labourWhere.add('p.client_id = ?');
      labourVars.add(Variable.withInt(settings.clientId!));
      materialWhere.add('p.client_id = ?');
      materialVars.add(Variable.withInt(settings.clientId!));
    }
    if (settings.projectId != null) {
      labourWhere.add('te.project_id = ?');
      labourVars.add(Variable.withInt(settings.projectId!));
      materialWhere.add('m.project_id = ?');
      materialVars.add(Variable.withInt(settings.projectId!));
    }
    if (settings.employeeId != null) {
      // Employee filter applies to labour rows only
      labourWhere.add('te.employee_id = ?');
      labourVars.add(Variable.withInt(settings.employeeId!));
    }
    if (settings.costCodeId != null) {
      labourWhere.add('te.cost_code_id = ?');
      labourVars.add(Variable.withInt(settings.costCodeId!));
      materialWhere.add('m.cost_code_id = ?');
      materialVars.add(Variable.withInt(settings.costCodeId!));
    }
    if (settings.startDate != null) {
      final startIso = settings.startDate!.toIso8601String();
      final startDate = startIso.substring(0, 10);
      labourWhere.add('te.start_time >= ?');
      labourVars.add(Variable.withString(startIso));
      materialWhere.add('m.purchase_date >= ?');
      materialVars.add(Variable.withString(startDate));
    }
    if (settings.endDate != null) {
      final endIso = settings.endDate!.add(const Duration(days: 1)).toIso8601String();
      final endDate = endIso.substring(0, 10);
      labourWhere.add('te.start_time < ?');
      labourVars.add(Variable.withString(endIso));
      materialWhere.add('m.purchase_date < ?');
      materialVars.add(Variable.withString(endDate));
    }

    final labourWhereStr = labourWhere.join(' AND ');
    final materialWhereStr = materialWhere.join(' AND ');

    final rows = await _db.customSelect('''
      SELECT
        strftime('%Y-%m-%d', te.start_time) AS date,
        'Labour' AS type,
        COALESCE(e.name, '') AS employee,
        '' AS supplier,
        COALESCE(te.work_details, '') AS description,
        ROUND(te.final_billed_duration_seconds / 3600.0, 2) AS hours,
        NULL AS unit_cost,
        ROUND(te.final_billed_duration_seconds / 3600.0 * COALESCE(te.hourly_rate, 0), 2) AS total_cost,
        COALESCE(cc.name, '') AS cost_code,
        CASE WHEN te.is_billed = 1 THEN 'Billed' ELSE 'Unbilled' END AS billed_status,
        te.start_time AS sort_key
      FROM time_entries te
      LEFT JOIN employees e ON te.employee_id = e.id
      LEFT JOIN projects p ON te.project_id = p.id
      LEFT JOIN cost_codes cc ON te.cost_code_id = cc.id
      WHERE $labourWhereStr

      UNION ALL

      SELECT
        COALESCE(strftime('%Y-%m-%d', m.purchase_date), '') AS date,
        'Material' AS type,
        '' AS employee,
        COALESCE(m.vendor_or_subtrade, '') AS supplier,
        COALESCE(m.description, m.item_name, '') AS description,
        NULL AS hours,
        ROUND(m.cost / NULLIF(COALESCE(m.quantity, 0), 0), 2) AS unit_cost,
        ROUND(m.cost, 2) AS total_cost,
        COALESCE(cc.name, '') AS cost_code,
        CASE WHEN m.is_billed = 1 THEN 'Billed' ELSE 'Unbilled' END AS billed_status,
        COALESCE(m.purchase_date, '') AS sort_key
      FROM materials m
      LEFT JOIN projects p ON m.project_id = p.id
      LEFT JOIN cost_codes cc ON m.cost_code_id = cc.id
      WHERE $materialWhereStr

      ORDER BY sort_key DESC
    ''', variables: [...labourVars, ...materialVars]).get();

    // Map SQL aliases to user-facing includes keys; strip sort_key
    const columnMap = {
      'date': 'Date',
      'type': 'Type (Labour/Material)',
      'employee': 'Employee',
      'supplier': 'Supplier',
      'description': 'Description',
      'hours': 'Hours',
      'unit_cost': 'Unit Cost',
      'total_cost': 'Total Cost',
      'cost_code': 'Cost Code',
      'billed_status': 'Billed Status',
    };

    return rows.map((r) {
      final raw = Map<String, dynamic>.from(r.data);
      final filtered = <String, dynamic>{};
      for (final entry in columnMap.entries) {
        if (includes[entry.value] == true) {
          filtered[entry.value] = raw[entry.key];
        }
      }
      return filtered;
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
