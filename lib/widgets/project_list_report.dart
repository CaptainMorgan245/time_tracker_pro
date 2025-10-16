// lib/widgets/project_list_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:time_tracker_pro/models.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

class ProjectListReport extends StatelessWidget {
  final List<ProjectSummaryViewModel> reportData;
  const ProjectListReport({super.key, required this.reportData});

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      // Create CSV data
      List<List<dynamic>> csvData = [
        // Header row
        ['Project', 'Client', 'Pricing Model', 'Hours', 'Labour Cost', 'Expenses', 'Total Cost', 'Billed Value', 'Profit/Loss'],
        // Data rows
        ...reportData.map((data) => [
          data.projectName,
          data.clientName ?? 'N/A',
          data.pricingModel,
          data.totalHours.toStringAsFixed(2),
          data.totalLabourCost.toStringAsFixed(2),
          data.totalExpenses.toStringAsFixed(2),
          (data.totalLabourCost + data.totalExpenses).toStringAsFixed(2),
          data.totalBilledValue.toStringAsFixed(2),
          data.profitLoss.toStringAsFixed(2),
        ]),
      ];

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/project_summary_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Project Summary Report',
        text: 'Project financial summary export',
      );

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
                  'Project Financial Summary',
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
            const Divider(),

            SizedBox(
              width: double.infinity,
              child: DataTable(
                columnSpacing: 12,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Expanded(child: Text('Project', style: TextStyle(fontWeight: FontWeight.bold)))),
                  DataColumn(label: Expanded(child: Text('Client', style: TextStyle(fontWeight: FontWeight.bold)))),
                  DataColumn(label: Text('Pricing', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('Billed Value', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('P/L', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: reportData.map((data) => DataRow(cells: [
                  DataCell(Text(data.projectName, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(data.clientName ?? 'N/A')),
                  DataCell(Text(data.pricingModel.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join(' '))),
                  DataCell(Text(data.totalHours.toStringAsFixed(1), textAlign: TextAlign.right)),
                  DataCell(Text(_currencyFormat.format(data.totalLabourCost + data.totalExpenses), textAlign: TextAlign.right)),
                  DataCell(Text(_currencyFormat.format(data.totalBilledValue), textAlign: TextAlign.right)),
                  DataCell(Text(_currencyFormat.format(data.profitLoss))),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}