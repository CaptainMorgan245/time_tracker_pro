// lib/analytics_screen.dart


import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: const Center(
        child: Text(
          'Analytics & Reports will be available here.',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models/project_summary.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<List<ProjectSummary>> _projectSummariesFuture;
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _projectSummariesFuture = DatabaseHelperV2.instance.getProjectSummaries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Profitability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadData();
              });
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder<List<ProjectSummary>>(
        future: _projectSummariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No active projects found.'));
          }

          final summaries = snapshot.data!;

          // Using a PaginatedDataTable for a professional look and feel
          return SingleChildScrollView(
            child: PaginatedDataTable(
              header: const Text('Active Projects Overview'),
              columns: const [
                DataColumn(label: Text('Project')),
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('Pricing')),
                DataColumn(label: Text('Total Hours'), numeric: true),
                DataColumn(label: Text('Total Cost'), numeric: true),
                DataColumn(label: Text('Billed Value'), numeric: true),
                DataColumn(label: Text('Profit/Loss'), numeric: true),
              ],
              source: _ProjectSummaryDataSource(summaries, _currencyFormatter),
              rowsPerPage: 10,
              showCheckboxColumn: false,
              columnSpacing: 16,
            ),
          );
        },
      ),
    );
  }
}

// Data source for the PaginatedDataTable
class _ProjectSummaryDataSource extends DataTableSource {
  final List<ProjectSummary> _summaries;
  final NumberFormat _currencyFormatter;

  _ProjectSummaryDataSource(this._summaries, this._currencyFormatter);

  @override
  DataRow? getRow(int index) {
    if (index >= _summaries.length) {
      return null;
    }
    final summary = _summaries[index];

    return DataRow(cells: [
      DataCell(Text(summary.projectName)),
      DataCell(Text(summary.clientName ?? 'N/A')),
      DataCell(Text(summary.pricingModel.capitalize())),
      DataCell(Text(summary.totalHours.toStringAsFixed(2))),
      DataCell(Text(_currencyFormatter.format(summary.totalCost))),
      DataCell(Text(summary.billedValue != null ? _currencyFormatter.format(summary.billedValue) : 'N/A')),
      DataCell(
        Text(
          summary.profitLoss != null ? _currencyFormatter.format(summary.profitLoss) : 'N/A',
          style: TextStyle(
            color: (summary.profitLoss ?? 0) >= 0 ? Colors.green.shade800 : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _summaries.length;

  @override
  int get selectedRowCount => 0;
}

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
*/