// lib/custom_report_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';

class CustomReportView extends StatefulWidget {
  final CustomReportSettings settings;
  final VoidCallback onClose;

  const CustomReportView({
    super.key,
    required this.settings,
    required this.onClose,
  });

  @override
  State<CustomReportView> createState() => _CustomReportViewState();
}

class _CustomReportViewState extends State<CustomReportView> {
  Future<List<Map<String, dynamic>>>? _reportDataFuture;

  Future<List<Map<String, dynamic>>> _getReportData(CustomReportSettings settings) async {
    switch (settings.subject) {
      case ReportSubject.projects:
        return [
          {'Project': 'Project X', 'Hours': 150, 'Cost': 15000.00, 'P/L': 3000.00},
          {'Project': 'Project Y', 'Hours': 200, 'Cost': 20000.00, 'P/L': 5000.00},
        ];
      case ReportSubject.personnel:
        return [
          {'Name': 'Employee A', 'Role': 'Dev', 'Hours': 40, 'Cost': 4000.00},
          {'Name': 'Employee B', 'Role': 'PM', 'Hours': 20, 'Cost': 2500.00},
        ];
      case ReportSubject.expenses:
        return [
          {'Date': '2025-01-01', 'Vendor': 'Vendor Z', 'Amount': 500.00, 'Project': 'Project X'},
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _getReportData(widget.settings);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Report: ${widget.settings.subject.name.toUpperCase()}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const Divider(),
            _buildSettingsSummary(),
            const SizedBox(height: 16),

            SizedBox(
              height: 400,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _reportDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading report: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data found for the selected criteria.'));
                  }
                  return _buildReportTable(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSummary() {
    final fields = widget.settings.includes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filters: Project ID=${widget.settings.projectId ?? "All"}, Client ID=${widget.settings.clientId ?? "All"}'),
        Text('Date Range: ${widget.settings.startDate != null ? DateFormat('yyyy-MM-dd').format(widget.settings.startDate!) : 'All Time'} to ${widget.settings.endDate != null ? DateFormat('yyyy-MM-dd').format(widget.settings.endDate!) : 'Current'}'),
        Text('Included Fields: $fields'),
      ],
    );
  }

  Widget _buildReportTable(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final columns = data.first.keys.map((key) =>
        DataColumn(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)))
    ).toList();

    final rows = data.map((rowMap) {
      return DataRow(
        cells: rowMap.values.map((value) {
          return DataCell(Text(value.toString()));
        }).toList(),
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
      ),
    );
  }
}