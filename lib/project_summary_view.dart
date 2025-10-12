// lib/project_summary_view.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/database_queries.dart';

class ProjectSummaryView extends StatelessWidget {
  final VoidCallback onClose;

  const ProjectSummaryView({super.key, required this.onClose});

  Future<List<Map<String, dynamic>>> _getReportData() async {
    final db = await DatabaseHelperV2.instance.database;
    final reportQueries = ReportQueries(db: db);

    // FEATURE: Add "Total Billable" to the list of columns to include.
    final Map<String, bool> hardCodedIncludes = {
      'Total Hours': true,
      'Billed Rate': true,
      'Billed Labor': true,
      'Expense Totals': true,
      'Total Billable': true, // Request the new total column
    };

    final data = await reportQueries.getProjectReportData(includes: hardCodedIncludes);

    if (data.isEmpty) return [];

    // REFINEMENT: Add "Total Billable" to the end of the column order.
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
      // Make all financial columns numeric so they right-align.
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
