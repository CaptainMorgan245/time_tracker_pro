// lib/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/custom_report_view.dart';
import 'package:time_tracker_pro/dropdown_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/widgets/project_summary_card.dart';
import 'package:time_tracker_pro/widgets/project_list_report.dart';
import 'package:time_tracker_pro/dialogs/select_data_dialog.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';
import 'package:time_tracker_pro/widgets/personnel_list_report.dart';
import 'package:time_tracker_pro/job_materials_repository.dart';
import 'package:time_tracker_pro/widgets/company_expenses_report.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/import_errors_report.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:time_tracker_pro/import_errors_notifier.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsView _currentView = AnalyticsView.none;
  ReportType _selectedReportType = ReportType.activeProjects;
  int? _selectedProjectId;
  final _dropdownRepo = DropdownRepository();
  final _projectRepo = ProjectRepository();
  final _employeeRepo = EmployeeRepository();
  final _materialsRepo = JobMaterialsRepository();
  List<DropdownItem> _projectsForDropdown = [];
  bool _isLoadingProjects = true;
  CustomReportSettings? _customReportSettings;

  Future<ProjectSummaryViewModel?>? _singleProjectCardFuture;
  Future<List<ProjectSummaryViewModel>>? _projectListTableFuture;
  Future<List<EmployeeSummaryViewModel>>? _employeeSummaryFuture;
  Future<List<Map<String, dynamic>>>? _companyExpensesFuture;

  @override
  void initState() {
    super.initState();
    ImportErrorsNotifier.instance.addListener(() {
      setState(() {}); // Rebuild when errors change
    });
    _loadProjects();
  }

  void _onErrorsChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    ImportErrorsNotifier.instance.removeListener(_onErrorsChanged);
    super.dispose();
  }


  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsForDropdown = [];
      _selectedProjectId = null;
      _currentView = AnalyticsView.none;
    });
    final bool fetchActive = _selectedReportType == ReportType.activeProjects;
    final projects = await _dropdownRepo.getProjectsByStatus(
        active: fetchActive);
    setState(() {
      _projectsForDropdown = projects;
      _isLoadingProjects = false;

      if (projects.length == 1) {
        _selectedProjectId = projects.first.id;
        _generateSingleSummaryCard(_selectedProjectId!);
      } else if (_currentView == AnalyticsView.none) {
        // Auto-generate project list report when page is empty
        _currentView = AnalyticsView.projectListTable;
        _projectListTableFuture = _projectRepo.getProjectListReport(
            activeOnly: _selectedReportType == ReportType.activeProjects);
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

  void _showCompanyExpenses() {
    setState(() {
      _currentView = AnalyticsView.companyExpenses;
      _companyExpensesFuture = _materialsRepo.getCompanyExpenses();
    });
  }

  Future<void> _importTimeEntries() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'json'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      final employeeNumber = jsonData['employee_id'] as String;  // e.g., "EMP-101"
      final entries = jsonData['entries'] as List;

      int imported = 0;
      int skipped = 0;
      List<String> errors = [];

      final db = await DatabaseHelperV2.instance.database;

      // Look up employee ID from employee_number
      final employeeResult = await db.query(
        'employees',
        columns: ['id'],
        where: 'employee_number = ? AND is_deleted = 0',
        whereArgs: [employeeNumber],
      );

      if (employeeResult.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Employee $employeeNumber not found in database')),
          );
        }
        return;
      }

      final employeeId = employeeResult.first['id'] as int;

      for (final entryData in entries) {
        final clientName = entryData['client'] as String;
        final projectName = entryData['project'] as String;
        final startTime = entryData['start_time'] as String;
        final endTime = entryData['end_time'] as String;
        final durationSeconds = entryData['duration_seconds'] as int;

        // Look up project_id from project name and client name
        final projectResult = await db.rawQuery('''
        SELECT p.id FROM projects p
        JOIN clients c ON p.client_id = c.id
        WHERE p.project_name = ? AND c.name = ?
      ''', [projectName, clientName]);

        if (projectResult.isEmpty) {
          errors.add('$clientName - $projectName: Not found in database');
          ImportErrorsNotifier.instance.addError(
            employeeNumber,
            'Client: $clientName | Project: $projectName | Start: $startTime',
            'Project not found in database',
          );
          continue;
        }

        final projectId = projectResult.first['id'] as int;

        // Check for duplicate
        final existing = await db.query(
          'time_entries',
          where: 'employee_id = ? AND project_id = ? AND start_time = ? AND end_time = ?',
          whereArgs: [employeeId, projectId, startTime, endTime],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          skipped++;
          continue;
        }

        // Insert entry
        try {
          await db.insert('time_entries', {
            'employee_id': employeeId,
            'project_id': projectId,
            'start_time': startTime,
            'end_time': endTime,
            'final_billed_duration_seconds': durationSeconds,
            'paused_duration': 0.0,
            'is_paused': 0,
            'is_deleted': 0,
          });
          imported++;
        } catch (e) {
          errors.add('$clientName - $projectName: Database error - $e');
          ImportErrorsNotifier.instance.addError(
            employeeNumber,
            'Client: $clientName | Project: $projectName | Start: $startTime',
            'Database error: $e',
          );
        }
      }

      // Show summary
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Summary'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Employee: $employeeNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('✓ Successfully imported: $imported entries'),
                  Text('⊘ Skipped (duplicates): $skipped entries'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('✗ Errors:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('${ errors.length} entries failed to import', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('View details in Analytics > Import Errors',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blue)),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Auto-switch to import errors view if errors exist
                  if (ImportErrorsNotifier.instance.errorCount > 0) {
                    setState(() {
                      _currentView = AnalyticsView.importErrors;
                    });
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _generateSingleSummaryCard(int projectId) {
    setState(() {
      _currentView = AnalyticsView.singleProjectCard;
      _singleProjectCardFuture = _projectRepo.getProjectSummary(projectId);
    });
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
              return Center(
                  child: Text('Error loading summary: ${snapshot.error}'));
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
              return Center(
                  child: Text('Error loading report: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('No projects found for this report type.'));
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
              return Center(child: Text(
                  'Error loading personnel summary: ${snapshot.error}'));
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

      case AnalyticsView.companyExpenses:
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _companyExpensesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error loading expenses: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No company expenses found.'));
            }
            return CompanyExpensesReport(reportData: snapshot.data!);
          },
        );

      case AnalyticsView.importErrors:
        final errors = ImportErrorsNotifier.instance.value;
        if (errors.isEmpty) {
          return const Center(child: Text('No import errors.'));
        }
        return ImportErrorsReport(errors: errors);

      case AnalyticsView.none:
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
            decoration: const InputDecoration(labelText: 'Report Type',
                border: OutlineInputBorder(),
                filled: true),
            value: _selectedReportType,
            items: const [
              DropdownMenuItem(value: ReportType.activeProjects,
                  child: Text('Active Projects')),
              DropdownMenuItem(value: ReportType.completedProjects,
                  child: Text('Completed Projects')),
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
                  : (_selectedReportType == ReportType.activeProjects
                  ? 'Select Active Project'
                  : 'Select Completed Project'),
              border: const OutlineInputBorder(),
              filled: true,
            ),
            items: _isLoadingProjects
                ? [
              const DropdownMenuItem(enabled: false,
                  child: Center(child: SizedBox(height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 3))))
            ]
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showProjectListReport,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.people_outline),
            label: const Text('Personnel Summary'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showPersonnelSummaryReport,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.checklist_rtl_outlined),
            label: const Text('Select Data'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showSelectDataDialog,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Company Expenses'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _showCompanyExpenses,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Import Time'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _importTimeEntries,
          ),
        ),
      ],
    );
  }
}