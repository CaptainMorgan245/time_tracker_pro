// lib/dropdown_repository.dart

import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class DropdownRepository {
  final dbHelper = DatabaseHelperV2.instance;

  Future<List<DropdownItem>> getClients() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients', where: 'is_active = 1', orderBy: 'name',
    );
    return List.generate(maps.length, (i) {
      return DropdownItem(id: maps[i]['id'], name: maps[i]['name']);
    });
  }

  Future<List<DropdownItem>> getProjects({int? clientId}) async {
    final db = await dbHelper.database;
    String? whereClause = 'is_completed = 0';
    List<dynamic>? whereArgs = [];

    if (clientId != null) {
      whereClause += ' AND client_id = ?';
      whereArgs.add(clientId);
    }
    if (whereArgs.isEmpty) { whereArgs = null; }

    final List<Map<String, dynamic>> maps = await db.query(
      'projects', where: whereClause, whereArgs: whereArgs, orderBy: 'project_name',
    );

    return List.generate(maps.length, (i) {
      return DropdownItem(id: maps[i]['id'], name: maps[i]['project_name']);
    });
  }

  Future<List<DropdownItem>> getEmployees() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'is_deleted = 0',
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) {
      return DropdownItem(id: maps[i]['id'], name: maps[i]['name']);
    });
  }

  Future<List<DropdownItem>> getProjectsByStatus({bool active = true}) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'is_completed = ?',
      whereArgs: [active ? 0 : 1],
      orderBy: 'project_name COLLATE NOCASE ASC',
    );
    return List.generate(maps.length, (i) {
      return DropdownItem(id: maps[i]['id'], name: maps[i]['project_name']);
    });
  }

  /// CRITICAL FIX: SQL now uses final_billed_duration_seconds / 3600.0 (seconds to hours).
  Future<Map<String, dynamic>> getProjectSummaryDetails(int projectId) async {
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        p.project_name,
        p.pricing_model,
        p.billed_hourly_rate,
        p.project_price, 
        c.name AS client_name,
        -- Confirmed SQL: Sums final billed seconds and converts to hours
        (SELECT IFNULL(SUM(t.final_billed_duration_seconds / 3600.0), 0.0) FROM time_entries t WHERE t.project_id = p.id) AS total_hours, 
        (SELECT IFNULL(SUM(cost), 0.0) FROM materials m WHERE m.project_id = p.id AND m.is_deleted = 0) AS total_expenses
      FROM projects p
      LEFT JOIN clients c ON p.client_id = c.id
      WHERE p.id = ?
    ''', [projectId]);

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return {};
    }
  }
}