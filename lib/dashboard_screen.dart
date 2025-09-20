// lib/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
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

  List<Project> _projects = [];
  List<Employee> _employees = [];
  List<Client> _clients = [];
  List<TimeEntry> _recentEntries = [];

  final GlobalKey<TimerAddFormState> _timerFormKey = GlobalKey<TimerAddFormState>();
  List<TimeEntry> _activeEntries = [];
  final Map<int, Timer> _activeTimers = {};
  final Map<int, Duration> _currentDurations = {};

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadActiveTimers();
  }

  @override
  void dispose() {
    _activeTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  Future<void> _loadData() async {
    final projects = await _projectRepo.getProjects();
    final employees = await _employeeRepo.getEmployees();
    final clients = await _clientRepo.getClients();
    final recentEntries = await _timeEntryRepo.getRecentTimeEntries(limit: 10);
    setState(() {
      _projects = projects;
      _employees = employees;
      _clients = clients;
      _recentEntries = recentEntries;
    });
  }

  Future<void> _loadActiveTimers() async {
    final activeEntries = await _timeEntryRepo.getActiveTimeEntries();
    for (var entry in activeEntries) {
      if (!_activeTimers.containsKey(entry.id)) {
        final initialDuration = DateTime.now().difference(entry.startTime) -
            Duration(seconds: entry.pausedDuration.toInt());
        _currentDurations[entry.id!] = initialDuration;
        _startTimerUpdate(entry);
      }
    }
    setState(() {
      _activeEntries = activeEntries;
    });
  }

  Future<void> _startTimer({
    Project? project,
    Employee? employee,
    String? workDetails,
    DateTime? startTime,
    DateTime? stopTime,
  }) async {
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project to start a timer.')),
      );
      return;
    }

    TimeEntry newEntry;
    if (startTime == null && stopTime == null) {
      newEntry = TimeEntry(
        projectId: project.id!,
        employeeId: employee?.id,
        startTime: DateTime.now(),
        workDetails: workDetails,
      );

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
      }
    }
  }

  void _startTimerUpdate(TimeEntry entry) {
    _activeTimers[entry.id!] = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimerDisplay(entry.id!);
    });
  }

  void _updateTimerDisplay(int entryId) {
    final entry = _activeEntries.firstWhere((e) => e.id == entryId);
    if (!entry.isPaused) {
      final elapsed = DateTime.now().difference(entry.startTime);
      setState(() {
        _currentDurations[entryId] = elapsed - Duration(seconds: entry.pausedDuration.toInt());
      });
    }
  }

  Future<void> _stopTimer(int entryId) async {
    final entry = _activeEntries.firstWhere((e) => e.id == entryId);

    final duration = DateTime.now().difference(entry.startTime) -
        Duration(seconds: entry.pausedDuration.toInt());

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
  }

  Future<void> _pauseTimer(int entryId) async {
    final entry = _activeEntries.firstWhere((e) => e.id == entryId);
    if (entry.isPaused) return;

    final now = DateTime.now();

    final pausedEntry = entry.copyWith(
      isPaused: true,
      pauseStartTime: now,
    );

    await _timeEntryRepo.updateTimeEntry(pausedEntry);

    setState(() {
      final index = _activeEntries.indexWhere((e) => e.id == entryId);
      _activeEntries[index] = pausedEntry;
    });
  }

  Future<void> _resumeTimer(int entryId) async {
    final entry = _activeEntries.firstWhere((e) => e.id == entryId);
    if (!entry.isPaused) return;

    final now = DateTime.now();
    final pauseDuration = now.difference(entry.pauseStartTime!).inSeconds.toDouble();

    final resumedEntry = entry.copyWith(
      isPaused: false,
      pausedDuration: entry.pausedDuration + pauseDuration,
    );

    await _timeEntryRepo.updateTimeEntry(resumedEntry);

    setState(() {
      final index = _activeEntries.indexWhere((e) => e.id == entryId);
      _activeEntries[index] = resumedEntry;
    });
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
      orElse: () => Client(name: 'Unknown', id: 0),
    );
    return client.name;
  }

  void _populateForm(TimeEntry entry) {
    final project = _projects.firstWhere((p) => p.id == entry.projectId);
    final employee = _employees.firstWhere((e) => e.id == entry.employeeId, orElse: () => Employee(name: 'N/A', isDeleted: true));

    _timerFormKey.currentState?.populateForm(project, employee, entry.workDetails ?? '');
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
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
                              '${_projects.firstWhere((p) => p.id == entry.projectId, orElse: () => Project(projectName: 'Unknown', clientId: 0)).projectName} - ${_formatDuration(duration)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Emp: ${_employees.firstWhere((e) => e.id == entry.employeeId, orElse: () => Employee(name: 'Unknown', isDeleted: true)).name} | Details: ${entry.workDetails ?? "N/A"}',
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
                              _projects.firstWhere((p) => p.id == entry.projectId, orElse: () => Project(projectName: 'Unknown', clientId: 0)).projectName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            subtitle: Text(
                              'Emp: ${_employees.firstWhere((e) => e.id == entry.employeeId, orElse: () => Employee(name: 'Unknown', isDeleted: true)).name} | ${DateFormat('MMM d, yyyy').format(entry.startTime)}',
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Time',
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