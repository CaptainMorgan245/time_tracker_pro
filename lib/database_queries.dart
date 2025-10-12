// lib/database_queries.dart

import 'package:sqflite/sqflite.dart';

class ReportQueries {
  final Database db;

  ReportQueries({required this.db});
  Future<List<Map<String, dynamic>>> getProjectReportData({
    required Map<String, bool> includes,
    int? projectId,
    int? clientId,
    String? startDate,
    String? endDate,
  }) async {
    List<String> selectClauses = ['p.project_name AS Project'];

    Set<String> joins = {'LEFT JOIN clients c ON p.client_id = c.id'};

    // BUG FIX: Added '?? false' to every condition to handle nulls correctly.
    if ((includes['Total Hours'] ?? false) ||
        (includes['Billed Labor'] ?? false) ||
        (includes['Total Billable'] ?? false)) {
      if (!joins.contains(
          'LEFT JOIN time_entries te ON p.id = te.project_id AND te.is_deleted = 0')) {
        joins.add(
            'LEFT JOIN time_entries te ON p.id = te.project_id AND te.is_deleted = 0');
      }
    }
    // BUG FIX: Added '?? false' to every condition here as well.
    if ((includes['Expense Totals'] ?? false) ||
        (includes['Total Billable'] ?? false)) {
      if (!joins.contains(
          'LEFT JOIN materials m ON p.id = m.project_id AND m.is_deleted = 0')) {
        joins.add(
            'LEFT JOIN materials m ON p.id = m.project_id AND m.is_deleted = 0');
      }
    }

    if (includes['Total Hours'] ?? false) {
      selectClauses.add(
          'COALESCE(SUM(DISTINCT te.final_billed_duration_seconds) / 3600.0, 0) AS "Total Hours"');
    }

    if (includes['Billed Rate'] ?? false) {
      selectClauses.add('''
        CASE
          WHEN p.pricing_model = 'hourly' THEN '\$' || printf('%.2f', p.billed_hourly_rate) || '/hr'
          ELSE p.pricing_model
        END AS "Billed Rate"
      ''');
    }

    if (includes['Expense Totals'] ?? false) {
      selectClauses.add('COALESCE(SUM(DISTINCT m.cost), 0) AS "Expense Totals"');
    }

    final laborCalculation =
        '(COALESCE(SUM(DISTINCT te.final_billed_duration_seconds), 0) / 3600.0) * p.billed_hourly_rate';
    final expenseCalculation = 'COALESCE(SUM(DISTINCT m.cost), 0)';

    if (includes['Billed Labor'] ?? false) {
      selectClauses.add('''
        CASE
          WHEN p.pricing_model = 'hourly' 
          THEN ${laborCalculation}
          ELSE 0.0
        END AS "Billed Labor"
      ''');
    }

    if (includes['Total Billable'] ?? false) {
      selectClauses.add('''
        CASE
          WHEN p.pricing_model = 'hourly' 
          THEN ${laborCalculation} + ${expenseCalculation}
          ELSE ${expenseCalculation}
        END AS "Total Billable"
      ''');
    }

    String query = '''
      SELECT
        ${selectClauses.join(',\n        ')}
      FROM projects p
      ${joins.join('\n      ')}
      GROUP BY p.id, p.project_name, c.name
    ''';

    print("Executing Project Report Query (With Total Billable): $query");

    try {
      final result = await db.rawQuery(query);
      if (result.isEmpty) return [];

      return result;
    } catch (e) {
      print("Error executing query: $e");
      throw Exception(
          "Failed to load report data. Please check query syntax.\nError: $e");
    }
  }
}
