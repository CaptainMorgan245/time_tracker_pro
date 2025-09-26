// lib/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/time_entry_repository.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'dart:async';
import 'package:time_tracker_pro/settings_screen.dart';
import 'package:time_tracker_pro/client_and_project_screen.dart';
import 'package:time_tracker_pro/timer_add_form.dart';
import 'package:time_tracker_pro/time_tracker_page.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/expenses_list_screen.dart';
import 'package:time_tracker_pro/models.dart' as app_models;
import 'package:time_tracker_pro/analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final ProjectRepository _projectRepo = ProjectRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final TimeEntryRepository _timeEntryRepo = TimeEntryRepository();
  final ClientRepository _clientRepo = ClientRepository();

  List<app_models.Project> _projects = [];
  List<app_models.Employee> _employees = [];
  List<app_models.Client> _clients = [];
  List<app_models.TimeEntry> _recentEntries = [];

  final GlobalKey<TimerAddFormState> _timerFormKey = GlobalKey<TimerAddFormState>();
  List<app_models.TimeEntry> _activeEntries = [];
  final Map<int, Timer> _activeTimers = {};
  final Map<int, Duration> _currentDurations = {};

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      _buildDashboardContent(),
      const ExpensesListScreen(),
      const AnalyticsScreen(),
    ];
    _loadData();
    _loadActiveTimers();
  }

  @override
  void dispose() {
    _activeTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  // start method: _loadData
  Future<void> _loadData() async {
    try {
      final projects = await _projectRepo.getProjects();
      final employees = await _employeeRepo.getEmployees();
      final clients = await _clientRepo.getClients();
      final allEntries = await _timeEntryRepo.getRecentTimeEntries(limit: 10);

      final filteredEntries = allEntries.where((entry) {
        final project = projects.firstWhere(
              (p) => p.id == entry.projectId,
          orElse: () => app_models.Project(projectName: 'Unknown', clientId: 0, isCompleted: true),
        );
        // FIX: Only include entries that have an endTime (i.e., are completed)
        return !entry.isDeleted && !project.isCompleted && entry.endTime != null;
      }).toList();

      setState(() {
        _projects = projects;
        _employees = employees;
        _clients = clients;
        _recentEntries = filteredEntries;
      });
    } catch (e) {
      // If loading fails, clear all lists to prevent crashes and log the error
      setState(() {
        _projects = [];
        _employees = [];
        _clients = [];
        _recentEntries = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }
  // end method: _loadData

  // start method: _loadActiveTimers
  Future<void> _loadActiveTimers() async {
    try {
      final activeEntries = await _timeEntryRepo.getActiveTimeEntries();
      final projects = await _projectRepo.getProjects();
      final employees = await _employeeRepo.getEmployees();

      final filteredEntries = activeEntries.where((entry) {
        final project = projects.firstWhere(
              (p) => p.id == entry.projectId,
          orElse: () => app_models.Project(projectName: 'Unknown', clientId: 0, isCompleted: true),
        );
        return !entry.isDeleted && !project.isCompleted;
      }).toList();

      // Clear old timers before loading new ones to prevent duplicate timers
      _activeTimers.values.forEach((timer) => timer.cancel());
      _activeTimers.clear();
      _currentDurations.clear();

      for (var entry in filteredEntries) {
        if (!_activeTimers.containsKey(entry.id)) {
          final now = DateTime.now();
          final elapsed = now.difference(entry.startTime!);
          final initialDuration = elapsed - Duration(seconds: entry.pausedDuration?.toInt() ?? 0);
          _currentDurations[entry.id!] = initialDuration;
          _startTimerUpdate(entry);
        }
      }
      setState(() {
        _activeEntries = filteredEntries;
      });
    } catch (e) {
      // If loading fails, clear active entries and timers
      _activeTimers.values.forEach((timer) => timer.cancel());
      _activeTimers.clear();
      _currentDurations.clear();
      setState(() {
        _activeEntries = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load active timers: $e')),
      );
    }
  }
  // end method: _loadActiveTimers

  Future<void> _startTimer({
    app_models.Project? project,
    app_models.Employee? employee,
    String? workDetails,
  }) async {
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project to start a timer.')),
      );
      return;
    }

    app_models.TimeEntry newEntry = app_models.TimeEntry(
      projectId: project.id!,
      employeeId: employee?.id,
      startTime: DateTime.now(),
      workDetails: workDetails,
      pausedDuration: 0.0,
    );
    try {
      final id = await _timeEntryRepo.insertTimeEntry(newEntry);
      final insertedEntry = await _timeEntryRepo.getTimeEntryById(id);

      if (insertedEntry != null) {
        setState(() {
          _activeEntries.add(insertedEntry);
          _currentDurations[insertedEntry.id!] = Duration.zero;
        });
        _startTimerUpdate(insertedEntry);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer started.')),
        );
        _timerFormKey.currentState?.resetForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start timer: $e')),
      );
    }
  }

  Future<void> _updateLiveEntry(
      String id,
      app_models.Project? project,
      app_models.Employee? employee,
      String? workDetails,
      DateTime? startTime,
      DateTime? stopTime,
      ) async {
    final entryId = int.tryParse(id);
    if (entryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid record ID.')),
      );
      return;
    }

    try {
      final existingEntry = _activeEntries.firstWhere((e) => e.id == entryId);

      final updatedEntry = existingEntry.copyWith(
        projectId: project?.id,
        employeeId: employee?.id,
        workDetails: workDetails,
      );

      await _timeEntryRepo.updateTimeEntry(updatedEntry);

      setState(() {
        final index = _activeEntries.indexWhere((e) => e.id == entryId);
        if (index != -1) {
          _activeEntries[index] = updatedEntry;
        }
      });
      _timerFormKey.currentState?.resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live timer updated.')),
      );
    } catch (e) {
      // If the timer is not found (Bad state: No element), we assume it's a new timer.
      _startTimer(project: project, employee: employee, workDetails: workDetails);
      _timerFormKey.currentState?.resetForm();
    }
  }

  void _startTimerUpdate(app_models.TimeEntry entry) {
    _activeTimers[entry.id!] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!entry.isPaused) {
        final elapsed = DateTime.now().difference(entry.startTime!);
        setState(() {
          _currentDurations[entry.id!] = elapsed - Duration(seconds: entry.pausedDuration?.toInt() ?? 0);
        });
      }
    });
  }

  Future<void> _stopTimer(int entryId) async {
    try {
      final entry = _activeEntries.firstWhere((e) => e.id == entryId);
      final duration = DateTime.now().difference(entry.startTime!) - Duration(seconds: entry.pausedDuration?.toInt() ?? 0);

      final stoppedEntry = entry.copyWith(
        endTime: DateTime.now(),
        isPaused: false,
        finalBilledDurationSeconds: duration.inSeconds.toDouble(),
      );

      await _timeEntryRepo.updateTimeEntry(stoppedEntry);

      setState(() {
        _activeEntries.removeWhere((e) => e.id == entryId);
        _currentDurations.remove(entryId);
      });

      _activeTimers[entryId]?.cancel();
      _activeTimers.remove(entryId);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop timer: $e')),
      );
    }
  }

  Future<void> _pauseTimer(int entryId) async {
    try {
      final entry = _activeEntries.firstWhere((e) => e.id == entryId);
      if (entry.isPaused) return;

      final pausedEntry = entry.copyWith(
        isPaused: true,
        pauseStartTime: DateTime.now(),
      );

      await _timeEntryRepo.updateTimeEntry(pausedEntry);

      setState(() {
        final index = _activeEntries.indexWhere((e) => e.id == entryId);
        _activeEntries[index] = pausedEntry;
        _activeTimers[entryId]?.cancel();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pause timer: $e')),
      );
    }
  }

  Future<void> _resumeTimer(int entryId) async {
    try {
      final entry = _activeEntries.firstWhere((e) => e.id == entryId);
      if (!entry.isPaused) return;

      final now = DateTime.now();
      final pauseDuration = now.difference(entry.pauseStartTime!).inSeconds.toDouble();

      final resumedEntry = entry.copyWith(
        isPaused: false,
        pausedDuration: (entry.pausedDuration ?? 0) + pauseDuration,
        pauseStartTime: null,
      );

      await _timeEntryRepo.updateTimeEntry(resumedEntry);

      setState(() {
        final index = _activeEntries.indexWhere((e) => e.id == entryId);
        _activeEntries[index] = resumedEntry;
      });
      _startTimerUpdate(resumedEntry);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resume timer: $e')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _getClientName(int clientId) {
    final client = _clients.firstWhere(
          (c) => c.id == clientId,
      orElse: () => app_models.Client(name: 'Unknown', id: 0),
    );
    return client.name;
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

  void _populateForm(app_models.TimeEntry entry) {
    try {
      final project = _projects.firstWhere((p) => p.id == entry.projectId);
      final employee = entry.employeeId != null
          ? _employees.firstWhere((e) => e.id == entry.employeeId)
          : null;

      _timerFormKey.currentState?.populateForm(entry);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot populate form with a completed or deleted record.')),
      );
    }
  }

  Widget _buildDashboardContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TimerAddForm(
            key: _timerFormKey,
            projects: _projects.where((p) => !p.isCompleted).toList(),
            employees: _employees.where((e) => !e.isDeleted).toList(),
            isLiveTimerForm: true,
            onSubmit: (project, employee, workDetails, startTime, stopTime) {
              _startTimer(
                project: project,
                employee: employee,
                workDetails: workDetails,
              );
            },
            onUpdate: (id, project, employee, workDetails, startTime, stopTime) {
              _updateLiveEntry(
                id,
                project,
                employee,
                workDetails,
                startTime,
                stopTime,
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    "Currently Active Timers",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _activeEntries.isEmpty
                      ? const Center(child: Text("No active timers."))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _activeEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _activeEntries[index];
                      final duration = _currentDurations[entry.id] ?? Duration.zero;
                      return Card(
                        color: Theme.of(context).cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 2.0),
                        child: ListTile(
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                          title: Text(
                            '${_getProjectName(entry.projectId)} - ${_formatDuration(duration)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            'Emp: ${_getEmployeeName(entry.employeeId)} | Details: ${entry.workDetails ?? "N/A"}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 80,
                                child: IconButton(
                                  icon: Icon(
                                    entry.isPaused ? Icons.play_arrow : Icons.pause,
                                    color: entry.isPaused ? Colors.green : Colors.amber,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    if (entry.isPaused) {
                                      _resumeTimer(entry.id!);
                                    } else {
                                      _pauseTimer(entry.id!);
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  icon: const Icon(Icons.stop, color: Colors.red, size: 24),
                                  onPressed: () => _stopTimer(entry.id!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Recent Activities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _recentEntries.isEmpty
                      ? const Center(child: Text('No recent activities found.'))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _recentEntries[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            _getProjectName(entry.projectId),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(
                            'Emp: ${_getEmployeeName(entry.employeeId)} | ${DateFormat('MMM d, yyyy').format(entry.startTime!)} | Details: ${entry.workDetails ?? "N/A"}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: Text(
                            _formatDuration(Duration(seconds: entry.finalBilledDurationSeconds?.toInt() ?? 0)),
                            style: Theme.of(context).textTheme.bodyMedium,
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = [
      _buildDashboardContent(),
      const ExpensesListScreen(),
      const AnalyticsScreen(),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Time Tracker Pro'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_pin_circle),
              title: const Text('Clients'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ClientAndProjectScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.construction),
              title: const Text('Projects'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ClientAndProjectScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Time Tracker'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TimeTrackerPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}