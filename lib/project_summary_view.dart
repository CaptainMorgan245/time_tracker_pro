// lib/project_summary_view.dart

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:time_tracker_pro/database/app_database.dart';

class ProjectSummaryView extends StatelessWidget {
  final VoidCallback onClose;

  const ProjectSummaryView({super.key, required this.onClose});

  Future<List<Map<String, dynamic>>> _getReportData() async {
    // Instructions 2 & 3: Replace db.rawQuery/db.query with AppDatabase.instance.customSelect(...).get()
    // and map results with rows.map((r) => r.data).toList()
    
    // We need to implement the query logic here since ReportQueries was using sqflite Database
    final Map<String, bool> includes = {
      'Total Hours': true,
      'Billed Rate': true,
      'Billed Labor': true,
      'Expense Totals': true,
      'Total Billable': true,
    };

    List<String> selectClauses = ['p.project_name AS Project'];
    Set<String> joins = {'LEFT JOIN clients c ON p.client_id = c.id'};

    if ((includes['Total Hours'] ?? false) ||
        (includes['Billed Labor'] ?? false) ||
        (includes['Total Billable'] ?? false)) {
      joins.add('LEFT JOIN time_entries te ON p.id = te.project_id AND te.is_deleted = 0');
    }
    if ((includes['Expense Totals'] ?? false) ||
        (includes['Total Billable'] ?? false)) {
      joins.add('LEFT JOIN materials m ON p.id = m.project_id AND m.is_deleted = 0');
    }

    if (includes['Total Hours'] ?? false) {
      selectClauses.add('COALESCE(SUM(DISTINCT te.final_billed_duration_seconds) / 3600.0, 0) AS "Total Hours"');
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

    final laborCalculation = '(COALESCE(SUM(DISTINCT te.final_billed_duration_seconds), 0) / 3600.0) * p.billed_hourly_rate';
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

    final rows = await AppDatabase.instance.customSelect(query).get();
    final data = rows.map((r) => r.data).toList();

    if (data.isEmpty) return [];

    final columnOrder = ['Project', 'Total Hours', 'Billed Rate', 'Billed Labor', 'Expense Totals', 'Total Billable'];
    final orderedData = data.map((originalMap) {
      final orderedMap = <String, dynamic>{};
      for (var col in columnOrder) {
        if (originalMap.containsKey(col)) {
          orderedMap[col] = originalMap[col];
        }
      }
      return orderedMap;
    }).toList();

    return orderedData;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getReportData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error fetching summary: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No project data found."));
        }
        final data = snapshot.data!;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Project Summary",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _buildHeaders(data),
                    rows: _buildRows(data),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildHeaders(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];
    return data.first.keys.map((key) {
      final isNumeric = key == 'Total Hours' || key == 'Expense Totals' || key == 'Billed Labor' || key == 'Total Billable';
      return DataColumn(
        label: Text(key),
        numeric: isNumeric,
      );
    }).toList();
  }

  List<DataRow> _buildRows(List<Map<String, dynamic>> data) {
    return data.map((rowMap) {
      return DataRow(
        cells: rowMap.values.map((cellValue) {
          if (cellValue is num) {
            return DataCell(Text(cellValue.toStringAsFixed(2)));
          }
          return DataCell(Text('$cellValue'));
        }).toList(),
      );
    }).toList();
  }
}
