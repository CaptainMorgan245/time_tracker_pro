// lib/widgets/company_expenses_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
final _dateFormat = DateFormat('yyyy-MM-dd');

class CompanyExpensesReport extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  const CompanyExpensesReport({super.key, required this.reportData});

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      List<List<dynamic>> csvData = [
        ['Date', 'Item', 'Category', 'Vendor', 'Cost', 'Description'],
        ...reportData.map((d) => [
          d['Date'],
          d['Item'],
          d['Category'],
          d['Vendor'],
          d['Cost'].toStringAsFixed(2),
          d['Description'],
        ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/company_expenses_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], subject: 'Company Expenses Report');

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
                  'Company Overhead Expenses',
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
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Expanded(child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)))),
                  DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
                rows: reportData.map((data) => DataRow(cells: [
                  DataCell(Text(_formatDate(data['Date']))),
                  DataCell(Text(data['Item'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(data['Category'] ?? 'N/A')),
                  DataCell(Text(data['Vendor'] ?? 'N/A')),
                  DataCell(Text(_currencyFormat.format(data['Cost']), textAlign: TextAlign.right)),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      if (date is String) {
        return _dateFormat.format(DateTime.parse(date));
      }
      return date.toString();
    } catch (e) {
      return 'Invalid Date';
    }
  }
}