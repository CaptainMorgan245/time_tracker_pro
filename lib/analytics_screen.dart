// lib/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/custom_report_view.dart';
import 'package:time_tracker_pro/dropdown_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';  // Include employee repository
import 'package:time_tracker_pro/widgets/project_summary_card.dart';
import 'package:time_tracker_pro/widgets/project_list_report.dart';
import 'package:time_tracker_pro/dialogs/select_data_dialog.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';
import 'package:time_tracker_pro/widgets/personnel_list_report.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // State variables
  AnalyticsView _currentView = AnalyticsView.none;
  ReportType _selectedReportType = ReportType.activeProjects;
  int? _selectedProjectId;
  final _dropdownRepo = DropdownRepository();
  final _projectRepo = ProjectRepository();
  final _employeeRepo = EmployeeRepository();  // Employee repository instance
  List<DropdownItem> _projectsForDropdown = [];
  bool _isLoadingProjects = true;
  CustomReportSettings? _customReportSettings;

  // Futures for asynchronous data loading
  Future<ProjectSummaryViewModel?>? _singleProjectCardFuture;
  Future<List<ProjectSummaryViewModel>>? _projectListTableFuture;
  Future<List<EmployeeSummaryViewModel>>? _employeeSummaryFuture;  // For employee summaries

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsForDropdown = [];
      _selectedProjectId = null;
      _currentView = AnalyticsView.none;
    });
    final bool fetchActive = _selectedReportType == ReportType.activeProjects;
    final projects = await _dropdownRepo.getProjectsByStatus(active: fetchActive);
    setState(() {
      _projectsForDropdown = projects;
      _isLoadingProjects = false;

      if (projects.length == 1) {
        _selectedProjectId = projects.first.id;
        _generateSingleSummaryCard(_selectedProjectId!);
      }
    });
  }

  void _showSelectDataDialog() {
    showDialog<CustomReportSettings>(
      context: context,
      builder: (BuildContext context) {
        return const SelectDataDialog();
      },
    ).then((settings) {
      if (settings != null) {
        setState(() {
          _customReportSettings = settings;
          _currentView = AnalyticsView.customReport;
        });
      }
    });
  }

  void _showProjectListReport() {
    setState(() {
      _currentView = AnalyticsView.projectListTable;
      _projectListTableFuture = _projectRepo.getProjectListReport(
          activeOnly: _selectedReportType == ReportType.activeProjects);
    });
  }

  void _showPersonnelSummaryReport() {
    setState(() {
      _currentView = AnalyticsView.personnelSummary;
      _employeeSummaryFuture = _employeeRepo.fetchEmployeeSummaries();
    });
  }

  void _generateSingleSummaryCard(int projectId) {
    setState(() {
      _currentView = AnalyticsView.singleProjectCard;
      _singleProjectCardFuture = _projectRepo.getProjectSummary(projectId);
    });
  }
  Future<void> _handleExport() async {
    switch (_currentView) {
      case AnalyticsView.projectListTable:
        await _exportProjectReport();
        break;
      case AnalyticsView.personnelSummary:
        await _exportPersonnelReport();
        break;
      case AnalyticsView.customReport:
        await _exportCustomReport();
        break;
      case AnalyticsView.singleProjectCard:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please view the full Project Summary table to export')),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No report selected to export')),
        );
    }
  }

  Future<void> _exportProjectReport() async {
    final data = await _projectListTableFuture;
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export')),
        );
      }
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        ['Project', 'Client', 'Pricing Model', 'Hours', 'Labour Cost', 'Expenses', 'Total Cost', 'Billed Value', 'Profit/Loss'],
        ...data.map((d) => [
          d.projectName,
          d.clientName ?? 'N/A',
          d.pricingModel,
          d.totalHours.toStringAsFixed(2),
          d.totalLabourCost.toStringAsFixed(2),
          d.totalExpenses.toStringAsFixed(2),
          (d.totalLabourCost + d.totalExpenses).toStringAsFixed(2),
          d.totalBilledValue.toStringAsFixed(2),
          d.profitLoss.toStringAsFixed(2),
        ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/project_summary_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], subject: 'Project Summary Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportPersonnelReport() async {
    final data = await _employeeSummaryFuture;
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export')),
        );
      }
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        ['Employee', 'Emp #', 'Role', 'Projects', 'Total Hours', 'Billed Value'],
        ...data.map((d) => [
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          children: [
            _buildFixedHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDynamicContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
// ADD NEW METHOD BELOW THIS LINE ↓
  Future<void> _exportCustomReport() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom report export coming soon - currently shows mock data')),
      );
    }
  }

  Widget _buildDynamicContent() {
    switch (_currentView) {
      case AnalyticsView.singleProjectCard:
        return FutureBuilder<ProjectSummaryViewModel?>(
          future: _singleProjectCardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading summary: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Project details not found.'));
            }
            final summaryData = snapshot.data!;
            return ProjectSummaryCard(summaryData: summaryData);
          },
        );

      case AnalyticsView.projectListTable:
        return FutureBuilder<List<ProjectSummaryViewModel>>(
          future: _projectListTableFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading report: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No projects found for this report type.'));
            }
            return ProjectListReport(reportData: snapshot.data!);
          },
        );

      case AnalyticsView.personnelSummary:
        return FutureBuilder<List<EmployeeSummaryViewModel>>(
          future: _employeeSummaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading personnel summary: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No employee data found.'));
            }
            return PersonnelListReport(reportData: snapshot.data!);
          },
        );

      case AnalyticsView.customReport:
        if (_customReportSettings == null) {
          return const Center(child: Text("No report settings selected."));
        }
        return CustomReportView(
          settings: _customReportSettings!,
          onClose: () => setState(() => _currentView = AnalyticsView.none),
        );

      case AnalyticsView.none:
      default:
        return const Center(child: Text('Select an option to view data.'));
    }
  }

  Widget _buildFixedHeader() {
    return Column(
      children: [
        _buildReportSelector(),
        const SizedBox(height: 16),
        _buildHorizontalActionButtons(),
      ],
    );
  }

  Widget _buildReportSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<ReportType>(
            decoration: const InputDecoration(labelText: 'Report Type', border: OutlineInputBorder(), filled: true),
            value: _selectedReportType,
            items: const [
              DropdownMenuItem(value: ReportType.activeProjects, child: Text('Active Projects')),
              DropdownMenuItem(value: ReportType.completedProjects, child: Text('Completed Projects')),
            ],
            onChanged: (ReportType? newValue) {
              if (newValue == null || newValue == _selectedReportType) return;
              setState(() {
                _selectedReportType = newValue;
              });
              _loadProjects();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            value: _selectedProjectId,
            decoration: InputDecoration(
              labelText: _isLoadingProjects
                  ? 'Loading...'
                  : (_selectedReportType == ReportType.activeProjects ? 'Select Active Project' : 'Select Completed Project'),
              border: const OutlineInputBorder(),
              filled: true,
            ),
            items: _isLoadingProjects
                ? [const DropdownMenuItem(enabled: false, child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3))))]
                : _projectsForDropdown.map((item) {
              return DropdownMenuItem<int>(
                value: item.id,
                child: Text(item.name),
              );
            }).toList(),
            onChanged: (int? value) {
              if (value == null) {
                setState(() {
                  _selectedProjectId = null;
                  _currentView = AnalyticsView.none;
                });
                return;
              }
              setState(() {
                _selectedProjectId = value;
              });
              _generateSingleSummaryCard(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Project Summary'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showProjectListReport,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.people_outline),
            label: const Text('Personnel Summary'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showPersonnelSummaryReport,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.checklist_rtl_outlined),
            label: const Text('Select Data'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showSelectDataDialog,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.ios_share),
            label: const Text('Export Details'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _handleExport, // Placeholder for future export functionality
          ),
        ),
      ],
    );
  }
}