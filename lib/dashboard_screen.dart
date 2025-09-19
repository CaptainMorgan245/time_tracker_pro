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

  Project? selectedProject;
  Employee? selectedEmployee;
  final TextEditingController _workDetailsController = TextEditingController();

  List<TimeEntry> _activeEntries = [];
  final Map<int, Timer> _activeTimers = {};
  final Map<int, Duration> _currentDurations = {};

  // start method: _onItemTapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  // end method: _onItemTapped

  // start method: initState
  @override
  void initState() {
    super.initState();
    _loadData();
    _loadActiveTimers();
  }
  // end method: initState

  // start method: dispose
  @override
  void dispose() {
    _activeTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }
  // end method: dispose

  // start method: _loadData
  Future<void> _loadData() async {
    final projects = await _projectRepo.getProjects();
    final employees = await _employeeRepo.getEmployees();
    final clients = await _clientRepo.getClients();
    setState(() {
      _projects = projects;
      _employees = employees;
      _clients = clients;
    });
  }
  // end method: _loadData

  // start method: _loadActiveTimers
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
  // end method: _loadActiveTimers

  // start method: _startTimer
  Future<void> _startTimer() async {
    if (selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project to start a timer.')),
      );
      return;
    }

    final newEntry = TimeEntry(
      projectId: selectedProject!.id!,
      employeeId: selectedEmployee?.id,
      startTime: DateTime.now(),
      workDetails: _workDetailsController.text,
    );

    final id = await _timeEntryRepo.insertTimeEntry(newEntry);
    final insertedEntry = await _timeEntryRepo.getTimeEntryById(id);

    if (insertedEntry != null) {
      setState(() {
        _activeEntries.add(insertedEntry);
        _currentDurations[insertedEntry.id!] = Duration.zero;
      });
      _startTimerUpdate(insertedEntry);
    }
  }
  // end method: _startTimer

  // start method: _startTimerUpdate
  void _startTimerUpdate(TimeEntry entry) {
    _activeTimers[entry.id!] = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimerDisplay(entry.id!);
    });
  }
  // end method: _startTimerUpdate

  // start method: _updateTimerDisplay
  void _updateTimerDisplay(int entryId) {
    final entry = _activeEntries.firstWhere((e) => e.id == entryId);
    if (!entry.isPaused) {
      final elapsed = DateTime.now().difference(entry.startTime);
      setState(() {
        _currentDurations[entryId] = elapsed - Duration(seconds: entry.pausedDuration.toInt());
      });
    }
  }
  // end method: _updateTimerDisplay

  // start method: _stopTimer
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
  // end method: _stopTimer

  // start method: _pauseTimer
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
  // end method: _pauseTimer

  // start method: _resumeTimer
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
  // end method: _resumeTimer

  // start method: _formatDuration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
  // end method: _formatDuration

  // start method: _getClientName
  String _getClientName(int clientId) {
    final client = _clients.firstWhere(
          (c) => c.id == clientId,
      orElse: () => Client(name: 'Unknown', id: 0),
    );
    return client.name;
  }
  // end method: _getClientName

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
                Navigator.pop(context); // Close the drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_pin_circle),
              title: const Text('Clients'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ClientAndProjectScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.construction),
              title: const Text('Projects'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ClientAndProjectScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Project>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  label: Text('Select Project'),
                ),
                value: selectedProject,
                items: _projects.map((project) {
                  return DropdownMenuItem<Project>(
                    value: project,
                    child: Text(project.projectName),
                  );
                }).toList(),
                onChanged: (Project? newValue) {
                  setState(() {
                    selectedProject = newValue;
                  });
                },
                hint: const Text('Select a project'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Employee>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  label: Text('Select Employee'),
                ),
                value: selectedEmployee,
                items: _employees.map((employee) {
                  return DropdownMenuItem<Employee>(
                    value: employee,
                    child: Text(employee.name),
                  );
                }).toList(),
                onChanged: (Employee? newValue) {
                  setState(() {
                    selectedEmployee = newValue;
                  });
                },
                hint: const Text('Select an employee'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _workDetailsController,
                decoration: const InputDecoration(
                  hintText: "Enter details about work performed...",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  label: Text('Work Details'),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Start New Timer'),
              ),
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
                  return SizedBox(
                    height: 60,
                    child: Card(
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
                          'Emp: ${_employees.firstWhere((e) => e.id == entry.employeeId, orElse: () => Employee(name: 'Unknown')).name} | Details: ${entry.workDetails ?? "N/A"}',
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
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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