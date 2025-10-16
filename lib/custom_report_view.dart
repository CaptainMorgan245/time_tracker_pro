// lib/custom_report_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';

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
  final _projectRepo = ProjectRepository();
  final _employeeRepo = EmployeeRepository();
  List<Map<String, dynamic>>? _currentData; // Store data for export

  Future<List<Map<String, dynamic>>> _getReportData(CustomReportSettings settings) async {
    switch (settings.subject) {
      case ReportSubject.projects:
        debugPrint('🔍 Custom Report Settings: Client=${settings.clientId}, Project=${settings.projectId}');
        return await _projectRepo.getCustomProjectReport(settings);
      case ReportSubject.personnel:
        return await _employeeRepo.getCustomPersonnelReport(settings);
      case ReportSubject.expenses:
        return [
          {'Date': '2025-01-01', 'Vendor': 'Vendor Z', 'Amount': 500.00, 'Project': 'Project X'},
        ];
    }
  }

  Future<void> _exportToCSV(BuildContext context) async {
    if (_currentData == null || _currentData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        _currentData!.first.keys.toList(), // Headers
        ..._currentData!.map((row) => row.values.toList()), // Data rows
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final subjectName = widget.settings.subject.name;
      final path = '${directory.path}/custom_${subjectName}_report_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], subject: 'Custom $subjectName Report');

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
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    _reportDataFuture = _getReportData(widget.settings);
  }

  @override
  void didUpdateWidget(CustomReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadReport();
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _exportToCSV(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
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
                  // Store data for export
                  _currentData = snapshot.data;
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
        DataColumn(label: Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)))
    ).toList();

    final rows = data.map((rowMap) {
      return DataRow(
        cells: rowMap.entries.map((entry) {
          String displayValue;

          if (entry.value is double) {
            if (entry.key.toLowerCase().contains('value') ||
                entry.key.toLowerCase().contains('cost') ||
                entry.key.toLowerCase().contains('price') ||
                entry.key.toLowerCase().contains('billed')) {
              displayValue = '\$${entry.value.toStringAsFixed(2)}';
            } else {
              displayValue = entry.value.toStringAsFixed(1);
            }
          } else {
            displayValue = entry.value?.toString() ?? 'N/A';
          }

          return DataCell(Text(displayValue));
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