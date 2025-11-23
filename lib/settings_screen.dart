// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/expenses_screen.dart';
import 'package:time_tracker_pro/personnel_screen.dart';
import 'package:time_tracker_pro/burden_rate_settings_screen.dart';
import 'package:time_tracker_pro/help_support_screen.dart';


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

  // These controllers are now public so the child screen can access their text
  final TextEditingController employeeNumberPrefixController = TextEditingController();
  final TextEditingController nextEmployeeNumberController = TextEditingController();
  final TextEditingController backupFrequencyController = TextEditingController();
  final TextEditingController reportMonthsController = TextEditingController();
  final TextEditingController expenseMarkupPercentageController = TextEditingController();


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
    employeeNumberPrefixController.dispose();
    nextEmployeeNumberController.dispose();
    backupFrequencyController.dispose();
    reportMonthsController.dispose();
    expenseMarkupPercentageController.dispose();
    super.dispose();
  }
  // end method: dispose

  // start method: _loadSettings
  // start method: _loadSettings
  Future<void> _loadSettings() async {
    final loadedSettings = await _settingsService.loadSettings();
    setState(() {_settings = loadedSettings; // Corrected line, removed dead code
    employeeNumberPrefixController.text = _settings.employeeNumberPrefix ?? '';
    nextEmployeeNumberController.text = (_settings.nextEmployeeNumber ?? 1).toString();
    backupFrequencyController.text = _settings.autoBackupReminderFrequency.toString();
    reportMonthsController.text = _settings.defaultReportMonths.toString();
    expenseMarkupPercentageController.text = _settings.expenseMarkupPercentage.toStringAsFixed(2);
    });
  }
// end method: _loadSettings


  // MODIFIED: This method now also gets the current rate from the Burden Rate screen's controller
  // if it exists, to ensure it's not overwritten.
  Future<void> _saveSettings({double? currentBurdenRate}) async {
    final settings = _settings.copyWith(
        employeeNumberPrefix: employeeNumberPrefixController.text.isEmpty
            ? null
            : employeeNumberPrefixController.text,
        nextEmployeeNumber: int.tryParse(nextEmployeeNumberController.text),
        autoBackupReminderFrequency: int.tryParse(backupFrequencyController.text) ?? 10,
        defaultReportMonths: int.tryParse(reportMonthsController.text) ?? 3,
        expenseMarkupPercentage: double.tryParse(expenseMarkupPercentageController.text) ?? 0.0,
        // If a burden rate is passed, use it. Otherwise, keep the existing one.
        companyHourlyRate: currentBurdenRate ?? _settings.companyHourlyRate,
        setupCompleted: true,  // <-- ADDED: Mark setup as complete when saving
    );

    // The corrected code
    await _settingsService.saveSettings(settings);

    if (!mounted) return; // This is the fix. It checks if the widget is still on screen.
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
                // ... (No changes to the UI cards below this point)
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
                                controller: employeeNumberPrefixController, // Use public controller
                                decoration: const InputDecoration(
                                  labelText: 'Employee Number Prefix',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: nextEmployeeNumberController, // Use public controller
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
                            // This is the new, corrected "Time Rounding" block
                            Expanded(
                              child: DropdownButton<int>(
                                value: _settings.timeRoundingInterval,
                                isExpanded: true, // This makes it fill the available space
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
                            // This is the new, corrected block
                            Expanded(
                              child: DropdownButton<String>(
                                value: _settings.measurementSystem,
                                isExpanded: true, // This makes it fill the available space
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
                                'Backup Reminder: Shows a reminder to backup your data every X times you open the app. Set to 0 to disable reminders. Dismissing the reminder resets the counter.\n\nDefault Report Period: Default number of months to display in quick reports. You can still override this when generating detailed reports. Prevents overwhelming displays of years of data.\n\nExpense Markup: Optional markup percentage for materials/expenses. Set to 0 for no markup (pass-through cost). Most contractors use 15-20% to cover time, risk, and cash flow.',
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
                                controller: backupFrequencyController, // Use public controller
                                decoration: const InputDecoration(
                                  labelText: 'Backup Reminder (app runs)',
                                  helperText: 'Set to 0 to disable',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  // No need for setState here as we read from controller on save
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: reportMonthsController, // Use public controller
                                decoration: const InputDecoration(
                                  labelText: 'Default Report Period (months)',
                                  helperText: 'Quick report timeframe',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  // No need for setState here as we read from controller on save
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: expenseMarkupPercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Expense Markup %',
                            helperText: 'Set to 0 for no markup (e.g., 15 for 15%)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _saveSettings, // This now saves all settings correctly
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

          PersonnelScreen(),
          ExpensesScreen(),
          HelpSupportScreen(),

          // **** CHANGE IS HERE ****
          // We now pass the controllers from this screen to the BurdenRateSettingsScreen
          BurdenRateSettingsScreen(
            employeeNumberPrefixController: employeeNumberPrefixController,
            nextEmployeeNumberController: nextEmployeeNumberController,
            backupFrequencyController: backupFrequencyController,
            reportMonthsController: reportMonthsController,
            settingsModel: _settings, // Also pass the model for dropdown values
          ),
        ],
      ),
    );
  }
// end method: build
}
// end class: _SettingsScreenState