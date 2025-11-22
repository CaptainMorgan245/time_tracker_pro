// lib/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/time_entry_repository.dart';
import 'dart:async';
import 'package:time_tracker_pro/settings_screen.dart';
import 'package:time_tracker_pro/client_and_project_screen.dart';
import 'package:time_tracker_pro/timer_add_form.dart';
import 'package:time_tracker_pro/time_tracker_page.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/database_viewer_screen.dart';
import 'package:time_tracker_pro/models.dart' as app_models;
import 'package:time_tracker_pro/analytics_screen.dart';
import 'package:time_tracker_pro/cost_entry_screen.dart';
import 'package:time_tracker_pro/app_bottom_nav_bar.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/data_management_screen.dart';


// START REUSABLE DRAWER WIDGET
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Data Management'),
            onTap: () {
              Navigator.of(context).pop(); // Close the drawer first
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DataManagementScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_pin_circle),
            title: const Text('Clients/Projects'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ClientAndProjectScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Time Entry Form'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TimeTrackerPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Database Viewer'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DatabaseViewerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
// END REUSABLE DRAWER WIDGET


class DashboardScreen extends StatefulWidget {
  final int initialIndex;
  const DashboardScreen({super.key, this.initialIndex = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _selectedIndex;

  final ProjectRepository _projectRepo = ProjectRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final TimeEntryRepository _timeEntryRepo = TimeEntryRepository();
  final dbHelper = DatabaseHelperV2.instance;

  final ValueNotifier<List<app_models.Project>> _projectsNotifier = ValueNotifier([]);
  final ValueNotifier<List<app_models.Employee>> _employeesNotifier = ValueNotifier([]);

  List<app_models.AllRecordViewModel> _recentActivities = [];

  List<app_models.Project> _allProjectsForLookup = [];
  List<app_models.Employee> _allEmployeesForLookup = [];

  final GlobalKey<TimerAddFormState> _timerFormKey = GlobalKey<TimerAddFormState>();
  List<app_models.TimeEntry> _activeEntries = [];
  final Map<int, Timer> _activeTimers = {};
  final Map<int, Duration> _currentDurations = {};

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadData();
    _loadActiveTimers();
    dbHelper.databaseNotifier.addListener(_reloadData);
  }

  @override
  void dispose() {
    dbHelper.databaseNotifier.removeListener(_reloadData);
    _projectsNotifier.dispose();
    _employeesNotifier.dispose();
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _reloadData() {
    _loadData();
    _loadActiveTimers();
  }

  Future<void> _loadData() async {
    try {
      final projects = await _projectRepo.getProjects();
      final employees = await _employeeRepo.getEmployees();

      // 💥 CRITICAL REFACTOR: Use the dedicated query
      final recentTimeActivities = await dbHelper.getDashboardTimeEntries();

      if (!mounted) return;

      // --- START: Removed Redundant/Inefficient Dart Filtering Logic ---
      // The database query now handles:
      // 1. Time entries only.
      // 2. Last 7 days filtering.
      // 3. Active projects filtering (is_completed = 0).
      // 4. Sorting by date DESC.
      // The following code block has been removed:
      /*
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentTimeActivities = allRecentActivities
          .where((record) {
            // ... lots of debugPrint statements removed
            if (record.type != app_models.RecordType.time) {
              return false;
            }
            if (record.date.isBefore(sevenDaysAgo)) {
              return false;
            }
            try {
              final parts = record.categoryOrProject.split(' - ');
              final projectName = parts.length > 1 ? parts.sublist(1).join(' - ') : record.categoryOrProject;
              final project = projects.firstWhere(
                    (p) => p.projectName == projectName,
              );
              return !project.isCompleted;
            } catch (e) {
              return false;
            }
          })
          .toList();
      recentTimeActivities.sort((a, b) => b.date.compareTo(a.date));
      */
      // --- END: Removed Redundant/Inefficient Dart Filtering Logic ---

      final sortedProjects = projects.where((p) => !p.isCompleted).toList();
      sortedProjects.sort((a, b) => b.id!.compareTo(a.id!));

      _projectsNotifier.value = sortedProjects;
      _employeesNotifier.value = employees.where((e) => !e.isDeleted).toList();

      setState(() {
        _recentActivities = recentTimeActivities;
        _allProjectsForLookup = projects;
        _allEmployeesForLookup = employees;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dashboard data: $e')),
      );
    }
  }


  Future<void> _loadActiveTimers() async {
    try {
      final activeEntries = await _timeEntryRepo.getActiveTimeEntries();
      final projects = await _projectRepo.getProjects();

      if (!mounted) return;

      final filteredEntries = activeEntries.where((entry) {
        final project = projects.firstWhere(
              (p) => p.id == entry.projectId,
          // START FIX: Provide required 'pricingModel' parameter
          orElse: () => const app_models.Project(projectName: 'Unknown', clientId: 0, isCompleted: true, pricingModel: 'unknown'),
          // END FIX
        );
        return !entry.isDeleted && !project.isCompleted;
      }).toList();

      for (final timer in _activeTimers.values) {
        timer.cancel();
      }
      _activeTimers.clear();
      _currentDurations.clear();

      for (var entry in filteredEntries) {
        if (!_activeTimers.containsKey(entry.id)) {
          final now = DateTime.now();
          final elapsed = now.difference(entry.startTime);
          // START FIX: Use .inSeconds instead of .toInt()
          final initialDuration = elapsed - entry.pausedDuration;
          // END FIX
          _currentDurations[entry.id!] = initialDuration;
          _startTimerUpdate(entry);
        }
      }
      if (mounted) {
        setState(() {
          _activeEntries = filteredEntries;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load active timers: $e')),
      );
    }
  }

  String _getProjectName(int projectId) {
    try {
      return _allProjectsForLookup.firstWhere((p) => p.id == projectId).projectName;
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getEmployeeName(int? employeeId) {
    if (employeeId == null) return 'N/A';
    try {
      return _allEmployeesForLookup.firstWhere((e) => e.id == employeeId).name;
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildDashboardContent() {
    final activeTimerIds = _activeEntries.map((e) => e.id).toSet();
    final filteredRecentActivities = _recentActivities.where((record) {
      return !activeTimerIds.contains(record.id);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TimerAddForm(
            key: _timerFormKey,
            projectsNotifier: _projectsNotifier,
            employeesNotifier: _employeesNotifier,
            isLiveTimerForm: true,
            onSubmit: (project, employee, workDetails, startTime, stopTime) {
              _startTimer(
                project: project,
                employee: employee,
                workDetails: workDetails,
                startTime: startTime,
              );
            },
            onUpdate: (id, project, employee, workDetails, startTime, stopTime) {
              _updateLiveEntry(id, project, employee, workDetails, startTime, stopTime);
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              IconButton(
                                icon: Icon(entry.isPaused ? Icons.play_arrow : Icons.pause, color: entry.isPaused ? Colors.green : Colors.amber),
                                onPressed: () => entry.isPaused ? _resumeTimer(entry.id!) : _pauseTimer(entry.id!),
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop, color: Colors.red),
                                onPressed: () => _stopTimer(entry.id!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Recent Activities (Last 7 Days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  filteredRecentActivities.isEmpty
                      ? const Center(child: Text('No recent activities found.'))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredRecentActivities.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecentActivities[index];
                      final isTime = record.type == app_models.RecordType.time;

                      return Card(
                        child: ListTile(
                          leading: Icon(isTime ? Icons.timer_outlined : Icons.shopping_cart_outlined, color: Theme.of(context).primaryColor),
                          title: Text(record.categoryOrProject, style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text(
                            '${DateFormat('MMM d, yyyy').format(record.date)} | Emp: ${_getEmployeeName(record.employeeId)} | ${record.description}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: Text(
                            isTime
                                ? _formatDuration(Duration(seconds: (record.value * 3600).toInt()))
                                : NumberFormat.currency(locale: 'en_US', symbol: '\$').format(record.value),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            if (isTime) {
                              app_models.Project? projectToPrefill;
                              app_models.Employee? employeeToPrefill;
                              final timeEntry = await _timeEntryRepo.getTimeEntryById(record.id);

                              if (timeEntry != null) {
                                try {
                                  projectToPrefill = _allProjectsForLookup.firstWhere(
                                          (p) => p.id == timeEntry.projectId);
                                } catch (e) {/* Project not found, remains null */}

                                if(timeEntry.employeeId != null){
                                  try {
                                    employeeToPrefill = _allEmployeesForLookup.firstWhere(
                                            (e) => e.id == timeEntry.employeeId);
                                  } catch (e) {/* Employee not found, remains null */}
                                }
                                _timerFormKey.currentState?.prefillForNewTimer(projectToPrefill, employeeToPrefill);
                              }
                            }
                          },
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
      const CostEntryScreen(),
      const AnalyticsScreen(),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Time Tracker Pro'),
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  void _startTimerUpdate(app_models.TimeEntry entry) {
    _activeTimers[entry.id!] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!entry.isPaused) {
        final elapsed = DateTime.now().difference(entry.startTime);
        if(mounted){
          setState(() {
            // START FIX: Use .inSeconds instead of .toInt()
            _currentDurations[entry.id!] = elapsed - entry.pausedDuration;
            // END FIX
          });
        }
      }
    });
  }

  Future<void> _startTimer({
    app_models.Project? project,
    app_models.Employee? employee,
    String? workDetails,
    DateTime? startTime,
  }) async {
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project to start a timer.')),
      );
      return;
    }

    final newEntry = app_models.TimeEntry(
      projectId: project.id!,
      employeeId: employee?.id,
      startTime: startTime ?? DateTime.now(),
      workDetails: workDetails,
      // START FIX: Use Duration.zero instead of 0.0
      pausedDuration: Duration.zero,
      // END FIX
    );

    try {
      await _timeEntryRepo.insertTimeEntry(newEntry);

      if (!mounted) return;

      _reloadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timer started.')),
      );
      _timerFormKey.currentState?.clearEmployeeAndDetails();
    } catch (e) {
      if (!mounted) return;
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

      if (!mounted) return;

      _reloadData();
      _timerFormKey.currentState?.resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live timer updated.')),
      );
    } catch (e) {
      _startTimer(
        project: project,
        employee: employee,
        workDetails: workDetails,
        startTime: startTime,
      );
      _timerFormKey.currentState?.resetForm();
    }
  }

  Future<void> _stopTimer(int entryId) async {
    try {
      final entry = _activeEntries.firstWhere((e) => e.id == entryId);
      // START FIX: Use .inSeconds instead of .toInt()
      final duration = DateTime.now().difference(entry.startTime) - entry.pausedDuration;
      // END FIX

      final stoppedEntry = entry.copyWith(
        endTime: DateTime.now(),
        isPaused: false,
        finalBilledDurationSeconds: duration.inSeconds.toDouble(),
      );

      await _timeEntryRepo.updateTimeEntry(stoppedEntry);

      if (!mounted) return;

      _activeTimers[entryId]?.cancel();
      _activeTimers.remove(entryId);

      _reloadData();
    } catch (e) {
      if (!mounted) return;
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

      if (!mounted) return;
      _reloadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pause timer: $e')),
      );
    }
  }

  Future<void> _resumeTimer(int entryId) async {
    try {
      final entry = _activeEntries.firstWhere((e) => e.id == entryId);
      if (!entry.isPaused || entry.pauseStartTime == null) return;

      final now = DateTime.now();
      // This is correct, pauseDuration is a Duration object.
      final pauseDuration = now.difference(entry.pauseStartTime!);

      final resumedEntry = entry.copyWith(
        isPaused: false,
        // START FIX: Correctly add two Durations together.
        pausedDuration: entry.pausedDuration + pauseDuration,
        // END FIX
        pauseStartTime: null, // Clear the pause start time
      );

      await _timeEntryRepo.updateTimeEntry(resumedEntry);

      if (!mounted) return;
      _reloadData();
    } catch (e) {
      if (!mounted) return;
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
}