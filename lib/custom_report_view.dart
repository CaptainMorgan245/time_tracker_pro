// lib/custom_report_view.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/database_queries.dart';
import 'package:time_tracker_pro/analytics_screen.dart'; // We need this for the CustomReportSettings model

class CustomReportView extends StatelessWidget {
  final CustomReportSettings settings;
  final VoidCallback onClose;

  const CustomReportView({
    super.key,
    required this.settings,
    required this.onClose,
  });

  Future<List<Map<String, dynamic>>> _getReportData(CustomReportSettings settings) async {
    final db = await DatabaseHelperV2.instance.database;
    final reportQueries = ReportQueries(db: db);

    switch (settings.subject) {
      case ReportSubject.projects:
        return await reportQueries.getProjectReportData(
          includes: settings.includes,
        );
      case ReportSubject.personnel:
        await Future.delayed(const Duration(seconds: 1));
        return [
          {'Personnel': 'John Doe (Placeholder)', 'Role': 'Developer', 'Total Billed': 15000},
        ];
      case ReportSubject.expenses:
        await Future.delayed(const Duration(seconds: 1));
        return [
          {'Expense': 'Server Hosting (Placeholder)', 'Amount': 150.00},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getReportData(settings),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error fetching report: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No data found for the selected criteria."));
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
                    Text(
                      "Custom Report: ${settings.subject.name[0].toUpperCase()}${settings.subject.name.substring(1)}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    columns: _buildCustomReportHeaders(data),
                    rows: _buildCustomReportRows(data),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildCustomReportHeaders(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];
    return data.first.keys.map((key) {
      final isNumeric = data.first[key] is num;
      return DataColumn(
        label: Text(key),
        numeric: isNumeric,
      );
    }).toList();
  }

  List<DataRow> _buildCustomReportRows(List<Map<String, dynamic>> data) {
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
