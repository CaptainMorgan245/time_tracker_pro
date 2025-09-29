// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/expenses_screen.dart';
import 'package:time_tracker_pro/personnel_screen.dart';
import 'package:time_tracker_pro/burden_rate_settings_screen.dart';

// start class: SettingsScreen
class SettingsScreen extends StatefulWidget {
  // start method: constructor
  const SettingsScreen({super.key});
  // end method: constructor

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
// end class: SettingsScreen

// start class: _SettingsScreenState
class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final SettingsService _settingsService = SettingsService.instance;

  SettingsModel _settings = SettingsModel();
  final TextEditingController _employeeNumberPrefixController = TextEditingController();
  final TextEditingController _nextEmployeeNumberController = TextEditingController();
  final TextEditingController _backupFrequencyController = TextEditingController();
  final TextEditingController _reportMonthsController = TextEditingController();

  // start method: initState
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
  }
  // end method: initState

  // start method: dispose
  @override
  void dispose() {
    _tabController.dispose();
    _employeeNumberPrefixController.dispose();
    _nextEmployeeNumberController.dispose();
    _backupFrequencyController.dispose();
    _reportMonthsController.dispose();
    super.dispose();
  }
  // end method: dispose

  // start method: _loadSettings
  Future<void> _loadSettings() async {
    final loadedSettings = await _settingsService.loadSettings();
    setState(() {
      _settings = loadedSettings ?? SettingsModel();
      _employeeNumberPrefixController.text = _settings.employeeNumberPrefix ?? '';
      _nextEmployeeNumberController.text = (_settings.nextEmployeeNumber ?? 1).toString();
      _backupFrequencyController.text = _settings.autoBackupReminderFrequency.toString();
      _reportMonthsController.text = _settings.defaultReportMonths.toString();
    });
  }
  // end method: _loadSettings

  // start method: _saveSettings
  Future<void> _saveSettings() async {
    final settings = _settings.copyWith(
      employeeNumberPrefix: _employeeNumberPrefixController.text.isEmpty
          ? null
          : _employeeNumberPrefixController.text,
      nextEmployeeNumber: int.tryParse(_nextEmployeeNumberController.text),
      autoBackupReminderFrequency: int.tryParse(_backupFrequencyController.text) ?? 10,
      defaultReportMonths: int.tryParse(_reportMonthsController.text) ?? 3,
    );

    await _settingsService.saveSettings(settings);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings Saved!')),
    );
  }
  // end method: _saveSettings

  // start method: _showHelpDialog
  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
  // end method: _showHelpDialog

  // start method: build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General & Reports'),
            Tab(text: 'Personnel'),
            Tab(text: 'Expenses'),
            Tab(text: 'Email'),
            Tab(text: 'Burden Rate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: General & Reports Settings
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'General Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: () => _showHelpDialog(
                        'General Settings',
                        'Configure basic app settings including employee numbering, time tracking behavior, measurement units, backup reminders, and default report periods.',
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Employee Number Settings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Employee Numbers',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.help_outline, size: 18),
                              onPressed: () => _showHelpDialog(
                                'Employee Numbers',
                                'Employee Number Prefix: Optional text to prefix all auto-generated employee numbers (e.g., "EMP" creates EMP001, EMP002).\n\nNext Employee Number: The next sequential number to assign. Auto-increments when adding new employees.',
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _employeeNumberPrefixController,
                                decoration: const InputDecoration(
                                  labelText: 'Employee Number Prefix',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _nextEmployeeNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Next Employee Number',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Time & Measurement Settings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Time & Measurement',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.help_outline, size: 18),
                              onPressed: () => _showHelpDialog(
                                'Time & Measurement',
                                'Time Rounding: Rounds billable time when timer stops.\n• No Rounding: Bill exact time worked\n• 15 Minutes: Rounds to nearest 15 min at 7.5 min (e.g., 1:05 → 1:00, 1:08 → 1:15)\n• 30 Minutes: Rounds to nearest 30 min at 15 min\nActual time is always preserved.\n\nMeasurement System: Choose metric (km/L) or imperial (miles/gallons) for distance and fuel tracking in expenses.',
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _settings.timeRoundingInterval,
                                decoration: const InputDecoration(
                                  labelText: 'Time Rounding',
                                ),
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('No Rounding')),
                                  DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                                  DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _settings = _settings.copyWith(
                                        timeRoundingInterval: value,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _settings.measurementSystem,
                                decoration: const InputDecoration(
                                  labelText: 'Measurement System',
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'metric', child: Text('Metric (km/L)')),
                                  DropdownMenuItem(value: 'imperial', child: Text('Imperial (mi/gal)')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _settings = _settings.copyWith(
                                        measurementSystem: value,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Backup & Reports Settings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Backup & Reports',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.help_outline, size: 18),
                              onPressed: () => _showHelpDialog(
                                'Backup & Reports',
                                'Backup Reminder: Shows a reminder to backup your data every X times you open the app. Set to 0 to disable reminders. Dismissing the reminder resets the counter.\n\nDefault Report Period: Default number of months to display in quick reports. You can still override this when generating detailed reports. Prevents overwhelming displays of years of data.',
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupFrequencyController,
                                decoration: const InputDecoration(
                                  labelText: 'Backup Reminder (app runs)',
                                  helperText: 'Set to 0 to disable',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final freq = int.tryParse(value);
                                  if (freq != null) {
                                    setState(() {
                                      _settings = _settings.copyWith(
                                        autoBackupReminderFrequency: freq,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _reportMonthsController,
                                decoration: const InputDecoration(
                                  labelText: 'Default Report Period (months)',
                                  helperText: 'Quick report timeframe',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final months = int.tryParse(value);
                                  if (months != null && months > 0) {
                                    setState(() {
                                      _settings = _settings.copyWith(
                                        defaultReportMonths: months,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Personnel (now using separate screen)
          const PersonnelScreen(),

          // Tab 3: Expenses
          const ExpensesScreen(),

          // Tab 4: Email
          const Center(child: Text('Email settings coming soon...')),

          // Tab 5: Burden Rate
          const BurdenRateSettingsScreen(),
        ],
      ),
    );
  }
// end method: build
}
// end class: _SettingsScreenState