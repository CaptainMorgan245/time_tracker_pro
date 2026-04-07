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
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/data_management_screen.dart';
import 'package:time_tracker_pro/cost_code_repository.dart';
import 'package:time_tracker_pro/manage_cost_codes_page.dart';
import 'package:time_tracker_pro/invoice_list_screen.dart';
import 'package:time_tracker_pro/screens/payroll_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/settings_model.dart';

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
              Navigator.of(context).pop();
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
            leading: const Icon(Icons.label_outline),
            title: const Text('Manage Cost Codes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ManageCostCodesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.payments),
            title: const Text('Payroll'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PayrollScreen()),
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
          if (kDebugMode)
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
  CostCodeRepository? _costCodeRepo;
  final dbHelper = AppDatabase.instance;

  final ValueNotifier<List<app_models.Project>> _projectsNotifier = ValueNotifier([]);
  final ValueNotifier<List<app_models.Employee>> _employeesNotifier = ValueNotifier([]);
  final ValueNotifier<List<app_models.CostCode>> _costCodesNotifier = ValueNotifier([]);

  List<app_models.AllRecordViewModel> _recentActivities = [];

  List<app_models.Project> _allProjectsForLookup = [];
  List<app_models.Employee> _allEmployeesForLookup = [];

  final GlobalKey<TimerAddFormState> _timerFormKey = GlobalKey<TimerAddFormState>();
  List<app_models.TimeEntry> _activeEntries = [];
  final Map<int, Timer> _activeTimers = {};
  final Map<int, Duration> _currentDurations = {};

  int _refreshKey = 0;
  SettingsModel? _settings;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _reloadData();
  }

  @override
  void dispose() {
    _projectsNotifier.dispose();
    _employeesNotifier.dispose();
    _costCodesNotifier.dispose();
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  // FIX: AppBottomNavBar uses 'onTap' not 'onItemTapped'
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _reloadData() {
    _loadData();
    _loadActiveTimers();
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      _settings = await SettingsService.instance.loadSettings();
      _costCodeRepo ??= CostCodeRepository();
      final projects = await _projectRepo.getProjects();
      final employees = await _employeeRepo.getEmployees();
      final costCodes = await _costCodeRepo!.getAllCostCodes();
      _costCodesNotifier.value = costCodes;

      final recentTimeActivities = await dbHelper.getDashboardTimeEntries();

      if (!mounted) return;

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
          orElse: () => const app_models.Project(projectName: 'Unknown', clientId: 0, isCompleted: true, pricingModel: 'unknown'),
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
          final initialDuration = elapsed - entry.pausedDuration;
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

  void _startTimer({
    required app_models.Project project,
    required app_models.Employee employee,
    app_models.CostCode? costCode,
    required String workDetails,
    required DateTime startTime,
  }) async {
    final newEntry = app_models.TimeEntry(
      projectId: project.id!,
      employeeId: employee.id!,
      costCodeId: costCode?.id,
      workDetails: workDetails,
      startTime: startTime,
      hourlyRate: employee.hourlyRate ?? 0.0,
    );

    final id = await _timeEntryRepo.insertTimeEntry(newEntry);
    final entryWithId = newEntry.copyWith(id: id);

    _startTimerUpdate(entryWithId);
    setState(() {
      _activeEntries.add(entryWithId);
      _currentDurations[id] = Duration.zero;
      _refreshKey++;
    });
  }

  void _startTimerUpdate(app_models.TimeEntry entry) {
    _activeTimers[entry.id!] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          final elapsed = now.difference(entry.startTime);
          _currentDurations[entry.id!] = elapsed - entry.pausedDuration;
        });
      }
    });
  }

  void _stopTimer(app_models.TimeEntry entry) async {
    final now = DateTime.now();
    final rawSeconds = now.difference(entry.startTime).inSeconds.toDouble() - entry.pausedDuration.inSeconds.toDouble();
    final updatedEntry = entry.copyWith(
      endTime: now,
      finalBilledDurationSeconds: _settings?.applyTimeRounding(rawSeconds) ?? rawSeconds,
    );

    await _timeEntryRepo.updateTimeEntry(updatedEntry);
    _activeTimers[entry.id!]?.cancel();
    _activeTimers.remove(entry.id);
    _currentDurations.remove(entry.id);

    setState(() {
      _activeEntries.removeWhere((e) => e.id == entry.id);
      _refreshKey++;
    });
  }

  // FIX: id is int, all params match _updateLiveEntry signature
  void _updateLiveEntry(int id, app_models.Project project, app_models.Employee employee, app_models.CostCode? costCode, String workDetails, DateTime startTime, DateTime? stopTime) async {
    final entry = _activeEntries.firstWhere((e) => e.id == id);
    final updatedEntry = entry.copyWith(
      projectId: project.id!,
      employeeId: employee.id!,
      costCodeId: costCode?.id,
      workDetails: workDetails,
      startTime: startTime,
      endTime: stopTime,
    );

    await _timeEntryRepo.updateTimeEntry(updatedEntry);
    if (stopTime != null) {
      _activeTimers[id]?.cancel();
      _activeTimers.remove(id);
      _currentDurations.remove(id);
      setState(() {
        _activeEntries.removeWhere((e) => e.id == id);
        _refreshKey++;
      });
    } else {
      final now = DateTime.now();
      final elapsed = now.difference(startTime);
      _currentDurations[id] = elapsed - entry.pausedDuration;

      setState(() {
        final index = _activeEntries.indexWhere((e) => e.id == id);
        _activeEntries[index] = updatedEntry;
        _refreshKey++;
      });
    }
  }

  void _editActiveEntry(app_models.TimeEntry entry) {
    final costCode = entry.costCodeId != null
        ? _costCodesNotifier.value.firstWhere((cc) => cc.id == entry.costCodeId)
        : null;

    // FIX: TimerAddForm uses populateForm(), not editEntry()
    // Build a minimal TimeEntry to pass to populateForm
    _timerFormKey.currentState?.populateForm(
      app_models.TimeEntry(
        id: entry.id,
        projectId: entry.projectId,
        employeeId: entry.employeeId,
        costCodeId: costCode?.id,
        workDetails: entry.workDetails,
        startTime: entry.startTime,
        endTime: entry.endTime,
        hourlyRate: entry.hourlyRate,
        finalBilledDurationSeconds: entry.finalBilledDurationSeconds,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
            costCodesNotifier: _costCodesNotifier,
            isLiveTimerForm: true,
            onSubmit: (project, employee, costCode, workDetails, startTime, stopTime) {
              // FIX: guard nulls before calling _startTimer which requires non-null
              if (project != null && employee != null && startTime != null) {
                _startTimer(
                  project: project,
                  employee: employee,
                  costCode: costCode,
                  workDetails: workDetails ?? '',
                  startTime: startTime,
                );
              }
            },
            onUpdate: (id, project, employee, costCode, workDetails, startTime, stopTime) {
              // FIX: parse String id to int, guard nulls
              if (project != null && employee != null && startTime != null) {
                _updateLiveEntry(
                  int.parse(id),
                  project,
                  employee,
                  costCode,
                  workDetails ?? '',
                  startTime,
                  stopTime,
                );
              }
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                key: ValueKey(_refreshKey),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activeEntries.isNotEmpty) ...[
                    const Text(
                      'Active Timers',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._activeEntries.map((entry) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.blueGrey[50],
                      child: ListTile(
                        title: Text(
                          _getProjectName(entry.projectId),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Employee: ${_getEmployeeName(entry.employeeId)}'),
                            // FIX: workDetails is nullable
                            if (entry.workDetails?.isNotEmpty ?? false)
                              Text('Details: ${entry.workDetails}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(_currentDurations[entry.id] ?? Duration.zero),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () => _editActiveEntry(entry),
                            ),
                            IconButton(
                              icon: const Icon(Icons.stop_circle, color: Colors.red, size: 32),
                              onPressed: () => _stopTimer(entry),
                            ),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'Recent Activity (7 Days)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (filteredRecentActivities.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('No recent activities'),
                      ),
                    )
                  else
                    ...filteredRecentActivities.map((record) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: record.type == app_models.RecordType.time ? Colors.blue : Colors.green,
                          child: Icon(
                            record.type == app_models.RecordType.time ? Icons.access_time : Icons.attach_money,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(record.categoryOrProject),
                        subtitle: Text(
                          '${DateFormat('MMM d').format(record.date)} - ${record.description}\n'
                              'By: ${_getEmployeeName(record.employeeId)}',
                        ),
                        trailing: Text(
                          record.type == app_models.RecordType.time
                              ? '${record.value.toStringAsFixed(2)}h'
                              : '\$${record.value.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _currentScreenTitle {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Cost Entry';
      case 2: return 'Analytics';
      case 3: return 'Invoices';
      default: return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentScreenTitle),
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardContent(),
          const CostEntryScreen(),
          const AnalyticsScreen(),
          const InvoiceListScreen(),
        ],
      ),
      // FIX: AppBottomNavBar uses currentIndex/onTap not selectedIndex/onItemTapped
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
