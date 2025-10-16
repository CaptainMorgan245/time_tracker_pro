// lib/widgets/personnel_list_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:time_tracker_pro/models.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

class PersonnelListReport extends StatelessWidget {
  final List<EmployeeSummaryViewModel> reportData;
  const PersonnelListReport({super.key, required this.reportData});

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      List<List<dynamic>> csvData = [
        ['Employee', 'Emp #', 'Role', 'Projects', 'Total Hours', 'Billed Value'],
        ...reportData.map((d) => [
          d.employeeName,
          d.employeeNumber,
          d.roleTitle,
          d.projectsCount,
          d.totalHours.toStringAsFixed(2),
          d.totalBilledValue.toStringAsFixed(2),
        ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/personnel_summary_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], subject: 'Personnel Summary Report');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personnel Summary Report',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportToCSV(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: DataTable(
                columnSpacing: 12,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Expanded(child: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold)))),
                  DataColumn(label: Text('Emp #', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Projects', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('Billed Value', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
                rows: reportData.map((data) => DataRow(cells: [
                  DataCell(Text(data.employeeName, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(data.employeeNumber)),
                  DataCell(Text(data.roleTitle)),
                  DataCell(Text(data.projectsCount.toString())),
                  DataCell(Text(data.totalHours.toStringAsFixed(1), textAlign: TextAlign.right)),
                  DataCell(Text(_currencyFormat.format(data.totalBilledValue), textAlign: TextAlign.right)),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}