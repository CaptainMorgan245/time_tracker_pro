// lib/widgets/personnel_list_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

class PersonnelListReport extends StatelessWidget {
  final List<EmployeeSummaryViewModel> reportData;
  const PersonnelListReport({super.key, required this.reportData});

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
            Text(
              'Personnel Summary Report',
              style: Theme.of(context).textTheme.headlineSmall,
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