// lib/time_tracker_page.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart' as app_models;
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/time_entry_repository.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/timer_add_form.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeTrackerPage extends StatefulWidget {
  const TimeTrackerPage({super.key});

  @override
  State<TimeTrackerPage> createState() => _TimeTrackerPageState();
}

class _TimeTrackerPageState extends State<TimeTrackerPage> {
  final TimeEntryRepository _timeEntryRepo = TimeEntryRepository();
  final ProjectRepository _projectRepo = ProjectRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final ClientRepository _clientRepo = ClientRepository();
  final dbHelper = DatabaseHelperV2.instance;

  final GlobalKey<TimerAddFormState> _dialogFormKey = GlobalKey<TimerAddFormState>();

  final ValueNotifier<List<app_models.Project>> _projectsNotifier = ValueNotifier([]);
  final ValueNotifier<List<app_models.Employee>> _employeesNotifier = ValueNotifier([]);

  List<app_models.TimeEntry> _allEntries = [];
  List<app_models.Client> _clients = [];
  List<app_models.Project> _allProjects = [];
  List<app_models.Role> _roles = [];
  bool _isLoading = true;

  // Filter state - default to current year
  DateTime? _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime? _endDate = DateTime.now();
  int? _selectedClientId;
  int? _selectedProjectId;
  int? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadSavedDates();
    dbHelper.databaseNotifier.addListener(_loadData);
    _loadData();
  }

  Future<void> _loadSavedDates() async {
    final prefs = await SharedPreferences.getInstance();
    final startDateString = prefs.getString('time_records_start_date');
    final endDateString = prefs.getString('time_records_end_date');

    if (mounted) {
      setState(() {
        if (startDateString != null) {
          _startDate = DateTime.parse(startDateString);
        }
        if (endDateString != null) {
          _endDate = DateTime.parse(endDateString);
        }
      });
    }
  }

  @override
  void dispose() {
    dbHelper.databaseNotifier.removeListener(_loadData);
    _projectsNotifier.dispose();
    _employeesNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final allRecords = await dbHelper.getAllRecordsV2();
    final projects = await _projectRepo.getProjects();
    final employees = await _employeeRepo.getEmployees();
    final clients = await _clientRepo.getClients();

    // Load roles for employee rates
    final db = await dbHelper.database;
    final rolesData = await db.query('roles');
    final roles = rolesData.map((r) => app_models.Role.fromMap(r)).toList();

    if (!mounted) return;

    _projectsNotifier.value = projects.where((p) => !p.isCompleted).toList();
    _employeesNotifier.value = employees.where((e) => !e.isDeleted).toList();
    _allProjects = projects;
    _roles = roles;

    List<app_models.TimeEntry> filteredEntries = [];
    for (var record in allRecords) {
      if (record.type == app_models.RecordType.time) {
        final fullEntry = await _timeEntryRepo.getTimeEntryById(record.id);
        if (fullEntry != null && fullEntry.endTime != null && !fullEntry.isDeleted) {
          filteredEntries.add(fullEntry);
        }
      }
    }

    filteredEntries.sort((a, b) => b.startTime.compareTo(a.startTime));

    if (mounted) {
      setState(() {
        _allEntries = filteredEntries;
        _clients = clients;
        _isLoading = false;
      });
    }
  }

  List<app_models.TimeEntry> _getFilteredEntries() {
    return _allEntries.where((entry) {
      // Date range filter
      if (_startDate != null && entry.startTime.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && entry.startTime.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }

      // Employee filter
      if (_selectedEmployeeId != null && entry.employeeId != _selectedEmployeeId) {
        return false;
      }

      // Project filter
      if (_selectedProjectId != null && entry.projectId != _selectedProjectId) {
        return false;
      }

      // Client filter
      if (_selectedClientId != null) {
        final project = _allProjects.firstWhere(
              (p) => p.id == entry.projectId,
          orElse: () => app_models.Project(projectName: 'Unknown', clientId: -1, isCompleted: true, pricingModel: 'unknown'),
        );
        if (project.clientId != _selectedClientId) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _getClientName(int clientId) {
    try {
      return _clients.firstWhere((c) => c.id == clientId).name;
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getProjectName(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).projectName;
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getEmployeeName(int? employeeId) {
    if (employeeId == null) return 'N/A';
    try {
      return _employeesNotifier.value.firstWhere((e) => e.id == employeeId).name;
    } catch (e) {
      return 'Unknown';
    }
  }

  double _getHourlyRate(app_models.Project project, int? employeeId) {
    // For hourly projects, use the project's billed rate (what client pays)
    if (project.pricingModel == 'hourly' && project.billedHourlyRate != null) {
      return project.billedHourlyRate!;
    }

    // For fixed-price projects, use employee's rate to calculate labor cost
    if (employeeId != null) {
      try {
        final employee = _employeesNotifier.value.firstWhere((e) => e.id == employeeId);
        if (employee.titleId != null) {
          try {
            final role = _roles.firstWhere((r) => r.id == employee.titleId);
            return role.standardRate;
          } catch (e) {
            // Role not found
          }
        }
      } catch (e) {
        // Employee not found
      }
    }

    // No rate available - return 0
    return 0.0;
  }

  int _getProjectClientId(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).clientId;
    } catch (e) {
      return -1;
    }
  }

  double _calculateTotalHours(List<app_models.TimeEntry> entries) {
    return entries.fold(0.0, (sum, entry) {
      return sum + ((entry.finalBilledDurationSeconds ?? 0) / 3600);
    });
  }

  double _calculateTotalValue(List<app_models.TimeEntry> entries) {
    double total = 0.0;
    for (var entry in entries) {
      final project = _allProjects.firstWhere(
            (p) => p.id == entry.projectId,
        orElse: () => app_models.Project(projectName: 'Unknown', clientId: -1, isCompleted: true, pricingModel: 'unknown'),
      );
      final hours = (entry.finalBilledDurationSeconds ?? 0) / 3600;
      final rate = _getHourlyRate(project, entry.employeeId);
      total += hours * rate;
    }
    return total;
  }

  Future<void> _exportToCSV() async {
    final filteredEntries = _getFilteredEntries();

    if (filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to export')),
      );
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        ['Date', 'Start Time', 'Employee', 'Client', 'Project', 'Hours', 'Rate', 'Value', 'Work Details'],
      ];

      for (var entry in filteredEntries) {
        final project = _allProjects.firstWhere(
              (p) => p.id == entry.projectId,
          orElse: () => app_models.Project(projectName: 'Unknown', clientId: -1, isCompleted: true, pricingModel: 'unknown'),
        );
        final hours = (entry.finalBilledDurationSeconds ?? 0) / 3600;
        final rate = _getHourlyRate(project, entry.employeeId);
        final value = hours * rate;

        csvData.add([
          DateFormat('EEE M/d').format(entry.startTime),
          DateFormat('h:mm a').format(entry.startTime),
          _getEmployeeName(entry.employeeId),
          _getClientName(_getProjectClientId(entry.projectId)),
          _getProjectName(entry.projectId),
          hours.toStringAsFixed(2),
          rate.toStringAsFixed(2),
          value.toStringAsFixed(2),
          entry.workDetails ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/time_records_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], subject: 'Time Records Export');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Records exported successfully')),
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

  Future<void> _showAddRecordDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Time Record',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TimerAddForm(
                    key: _dialogFormKey,
                    projectsNotifier: _projectsNotifier,
                    employeesNotifier: _employeesNotifier,
                    isLiveTimerForm: false,
                    onSubmit: (project, employee, workDetails, startTime, stopTime) async {
                      await _submitManualEntry(
                        project: project,
                        employee: employee,
                        workDetails: workDetails,
                        startTime: startTime,
                        stopTime: stopTime,
                      );
                      if (mounted) Navigator.of(context).pop();
                    },
                    onUpdate: (id, project, employee, workDetails, startTime, stopTime) async {
                      await _updateManualEntry(
                        id: int.parse(id),
                        project: project,
                        employee: employee,
                        workDetails: workDetails,
                        startTime: startTime,
                        stopTime: stopTime,
                      );
                      if (mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditRecordDialog(app_models.TimeEntry entry) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _EditRecordDialog(
          entry: entry,
          projectsNotifier: _projectsNotifier,
          employeesNotifier: _employeesNotifier,
          onUpdate: (id, project, employee, workDetails, startTime, stopTime) async {
            await _updateManualEntry(
              id: id,
              project: project,
              employee: employee,
              workDetails: workDetails,
              startTime: startTime,
              stopTime: stopTime,
            );
            if (mounted) Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  Future<void> _submitManualEntry({
    required app_models.Project? project,
    required app_models.Employee? employee,
    required String? workDetails,
    required DateTime? startTime,
    required DateTime? stopTime,
  }) async {
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project.')),
      );
      return;
    }
    if (startTime == null || stopTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both start and stop times.')),
      );
      return;
    }

    final duration = stopTime.difference(startTime);

    final newEntry = app_models.TimeEntry(
      projectId: project.id!,
      employeeId: employee?.id,
      startTime: startTime,
      endTime: stopTime,
      workDetails: workDetails,
      finalBilledDurationSeconds: duration.inSeconds.toDouble(),
    );

    await _timeEntryRepo.insertTimeEntry(newEntry);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time record added.')),
      );
    }
  }

  Future<void> _updateManualEntry({
    required int id,
    required app_models.Project? project,
    required app_models.Employee? employee,
    required String? workDetails,
    required DateTime? startTime,
    required DateTime? stopTime,
  }) async {
    if (project == null || startTime == null || stopTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields.')),
      );
      return;
    }

    final duration = stopTime.difference(startTime);

    final updatedEntry = app_models.TimeEntry(
      id: id,
      projectId: project.id!,
      employeeId: employee?.id,
      startTime: startTime,
      endTime: stopTime,
      workDetails: workDetails,
      finalBilledDurationSeconds: duration.inSeconds.toDouble(),
    );

    await _timeEntryRepo.updateTimeEntry(updatedEntry);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time record updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredEntries = _getFilteredEntries();
    final totalHours = _calculateTotalHours(filteredEntries);
    final totalValue = _calculateTotalValue(filteredEntries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Records'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // FILTERS SECTION
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Date Range
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _startDate == null ? 'Start Date' : DateFormat('MM/dd/yy').format(_startDate!),
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2101),
                            );
                            if (date != null) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('time_records_start_date', date.toIso8601String());
                              setState(() => _startDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _endDate == null ? 'End Date' : DateFormat('MM/dd/yy').format(_endDate!),
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2101),
                            );
                            if (date != null) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('time_records_end_date', date.toIso8601String());
                              setState(() => _endDate = date);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Client and Project
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(
                            labelText: 'Client',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedClientId,
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All Clients')),
                            ..._clients.map((client) => DropdownMenuItem<int?>(
                              value: client.id,
                              child: Text(client.name),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedClientId = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(
                            labelText: 'Project',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedProjectId,
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All Projects')),
                            ..._allProjects.map((project) => DropdownMenuItem<int?>(
                              value: project.id,
                              child: Text(project.projectName),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedProjectId = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 3: Employee
                  DropdownButtonFormField<int?>(
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedEmployeeId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Employees')),
                      ..._employeesNotifier.value.map((employee) => DropdownMenuItem<int?>(
                        value: employee.id,
                        child: Text(employee.name),
                      )),
                    ],
                    onChanged: (value) => setState(() => _selectedEmployeeId = value),
                  ),
                  const SizedBox(height: 8),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: _showAddRecordDialog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: _exportToCSV,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // SUMMARY LINE at bottom
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'Records: ${filteredEntries.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          'Hours: ${totalHours.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          'Value: \$${totalValue.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RECORDS LIST
          Expanded(
            child: filteredEntries.isEmpty
                ? const Center(child: Text('No time records found.'))
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: filteredEntries.length,
              itemBuilder: (context, index) {
                final entry = filteredEntries[index];
                final project = _allProjects.firstWhere(
                      (p) => p.id == entry.projectId,
                  orElse: () => app_models.Project(projectName: 'Unknown', clientId: -1, isCompleted: true, pricingModel: 'unknown'),
                );
                final hours = (entry.finalBilledDurationSeconds ?? 0) / 3600;
                final rate = _getHourlyRate(project, entry.employeeId);
                final value = hours * rate;

                return Card(
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEE M/d').format(entry.startTime),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          DateFormat('h:mm a').format(entry.startTime),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    title: Text(
                      _getClientName(_getProjectClientId(entry.projectId)),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_getProjectName(entry.projectId)} - ${_getEmployeeName(entry.employeeId)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Hours: ${hours.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              '\$${value.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, color: Colors.green),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditRecordDialog(entry),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Separate dialog widget for editing that populates the form properly
class _EditRecordDialog extends StatefulWidget {
  final app_models.TimeEntry entry;
  final ValueNotifier<List<app_models.Project>> projectsNotifier;
  final ValueNotifier<List<app_models.Employee>> employeesNotifier;
  final Function(int, app_models.Project?, app_models.Employee?, String?, DateTime?, DateTime?) onUpdate;

  const _EditRecordDialog({
    required this.entry,
    required this.projectsNotifier,
    required this.employeesNotifier,
    required this.onUpdate,
  });

  @override
  State<_EditRecordDialog> createState() => _EditRecordDialogState();
}

class _EditRecordDialogState extends State<_EditRecordDialog> {
  final GlobalKey<TimerAddFormState> _formKey = GlobalKey<TimerAddFormState>();

  @override
  void initState() {
    super.initState();
    // Populate the form after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formKey.currentState?.populateForm(widget.entry);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Time Record',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TimerAddForm(
                key: _formKey,
                projectsNotifier: widget.projectsNotifier,
                employeesNotifier: widget.employeesNotifier,
                isLiveTimerForm: false,
                onSubmit: (project, employee, workDetails, startTime, stopTime) async {
                  // Should not be called in edit mode
                },
                onUpdate: (id, project, employee, workDetails, startTime, stopTime) async {
                  widget.onUpdate(
                    int.parse(id),
                    project,
                    employee,
                    workDetails,
                    startTime,
                    stopTime,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}