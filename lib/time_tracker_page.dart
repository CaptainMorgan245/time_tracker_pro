// lib/time_tracker_page.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/time_entry_repository.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/timer_add_form.dart';
import 'package:intl/intl.dart';

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

  final GlobalKey<TimerAddFormState> _timerFormKey = GlobalKey<TimerAddFormState>();

  List<TimeEntry> _allEntries = [];
  List<Project> _projects = [];
  List<Employee> _employees = [];
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allEntries = await _timeEntryRepo.getAllTimeEntries();
    final projects = await _projectRepo.getProjects();
    final employees = await _employeeRepo.getEmployees();
    final clients = await _clientRepo.getClients();

    final filteredEntries = allEntries.where((entry) {
      final project = projects.firstWhere(
            (p) => p.id == entry.projectId,
        orElse: () => Project(projectName: 'Unknown', clientId: 0, isCompleted: true),
      );
      return !entry.isDeleted && !project.isCompleted;
    }).toList();

    setState(() {
      _allEntries = filteredEntries;
      _projects = projects;
      _employees = employees;
      _clients = clients;
      _isLoading = false;
    });
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
      return _projects.firstWhere((p) => p.id == projectId).projectName;
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getEmployeeName(int? employeeId) {
    if (employeeId == null) return 'N/A';
    try {
      return _employees.firstWhere((e) => e.id == employeeId).name;
    } catch (e) {
      return 'Unknown';
    }
  }

  void _populateForm(TimeEntry entry) {
    _timerFormKey.currentState?.populateForm(entry);
  }

  Future<void> _submitManualEntry({
    required Project? project,
    required Employee? employee,
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

    final newEntry = TimeEntry(
      projectId: project.id!,
      employeeId: employee?.id,
      startTime: startTime,
      endTime: stopTime,
      workDetails: workDetails,
      finalBilledDurationSeconds: duration.inSeconds.toDouble(),
    );

    await _timeEntryRepo.insertTimeEntry(newEntry);
    await _loadData();
    _timerFormKey.currentState?.resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Time record added.')),
    );
  }

  Future<void> _updateManualEntry({
    required int id,
    required Project? project,
    required Employee? employee,
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

    final updatedEntry = TimeEntry(
      id: id,
      projectId: project.id!,
      employeeId: employee?.id,
      startTime: startTime,
      endTime: stopTime,
      workDetails: workDetails,
      finalBilledDurationSeconds: duration.inSeconds.toDouble(),
    );

    await _timeEntryRepo.updateTimeEntry(updatedEntry);
    await _loadData();
    _timerFormKey.currentState?.resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Time record updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Records'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TimerAddForm(
              key: _timerFormKey,
              projects: _projects.where((p) => !p.isCompleted).toList(),
              employees: _employees.where((e) => !e.isDeleted).toList(),
              isLiveTimerForm: false,
              onSubmit: (project, employee, workDetails, startTime, stopTime) {
                _submitManualEntry(
                  project: project,
                  employee: employee,
                  workDetails: workDetails,
                  startTime: startTime,
                  stopTime: stopTime,
                );
              },
              onUpdate: (id, project, employee, workDetails, startTime, stopTime) {
                _updateManualEntry(
                  id: int.parse(id),
                  project: project,
                  employee: employee,
                  workDetails: workDetails,
                  startTime: startTime,
                  stopTime: stopTime,
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'All Time Records',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _allEntries.isEmpty
                      ? const Center(child: Text('No time records found.'))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _allEntries[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            _getProjectName(entry.projectId),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(
                            'Client: ${_getClientName(_projects.firstWhere((p) => p.id == entry.projectId).clientId)} | Emp: ${_getEmployeeName(entry.employeeId)} | Details: ${entry.workDetails ?? "N/A"}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: Text(
                            '${DateFormat('MM/dd').format(entry.startTime!)}\n${_formatDuration(Duration(seconds: entry.finalBilledDurationSeconds?.toInt() ?? 0))}',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => _populateForm(entry),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}