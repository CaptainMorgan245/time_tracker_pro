// lib/dropdown_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class DropdownRepository {
  final _db = AppDatabase.instance;

  Future<List<DropdownItem>> getClients() async {
    final rows = await _db.customSelect(
      'SELECT id, name FROM clients WHERE is_active = 1 ORDER BY name',
    ).get();
    return rows.map((r) => DropdownItem(id: r.data['id'], name: r.data['name'])).toList();
  }

  Future<List<DropdownItem>> getProjects({int? clientId}) async {
    String query = 'SELECT id, project_name FROM projects WHERE is_completed = 0';
    List<Variable> vars = [];

    if (clientId != null) {
      query += ' AND client_id = ?';
      vars.add(Variable.withInt(clientId));
    }
    query += ' ORDER BY project_name';

    final rows = await _db.customSelect(query, variables: vars).get();
    return rows.map((r) => DropdownItem(id: r.data['id'], name: r.data['project_name'])).toList();
  }

  Future<List<DropdownItem>> getEmployees() async {
    final rows = await _db.customSelect(
      'SELECT id, name FROM employees WHERE is_deleted = 0 ORDER BY name',
    ).get();
    return rows.map((r) => DropdownItem(id: r.data['id'], name: r.data['name'])).toList();
  }

  Future<List<DropdownItem>> getProjectsByStatus({bool active = true}) async {
    final rows = await _db.customSelect(
      'SELECT id, project_name FROM projects WHERE is_completed = ? ORDER BY project_name COLLATE NOCASE ASC',
      variables: [Variable.withInt(active ? 0 : 1)],
    ).get();
    return rows.map((r) => DropdownItem(id: r.data['id'], name: r.data['project_name'])).toList();
  }

  /// CRITICAL FIX: SQL now calculates the true labor cost.
  Future<Map<String, dynamic>> getProjectSummaryDetails(int projectId) async {
    final rows = await _db.customSelect('''
    SELECT
      p.project_name,
      p.pricing_model,
      p.billed_hourly_rate,
      p.project_price, 
      c.name AS client_name,
      -- Sums final billed seconds and converts to hours
      (SELECT IFNULL(SUM(t.final_billed_duration_seconds / 3600.0), 0.0) 
       FROM time_entries t 
       WHERE t.project_id = p.id AND t.is_deleted = 0) AS total_hours,
      -- Sums all material costs for the project
      (SELECT IFNULL(SUM(m.cost), 0.0) 
       FROM materials m 
       WHERE m.project_id = p.id AND m.is_deleted = 0) AS total_expenses,
      -- total_hours is used by the caller to calculate labor cost at the correct rate
      0.0 AS total_labor_cost
    FROM projects p
    LEFT JOIN clients c ON p.client_id = c.id
    WHERE p.id = ?
  ''', variables: [Variable.withInt(projectId)]).get();

    return rows.isNotEmpty ? rows.first.data : {};
  }
}
