// lib/burden_rate_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/settings_model.dart';

// start class: BurdenRateSettingsScreen
class BurdenRateSettingsScreen extends StatefulWidget {
  // **** ADDED ****: These are the controllers from the parent screen.
  final TextEditingController employeeNumberPrefixController;
  final TextEditingController nextEmployeeNumberController;
  final TextEditingController backupFrequencyController;
  final TextEditingController reportMonthsController;
  final SettingsModel settingsModel; // And the settings model for dropdowns

  // **** MODIFIED ****: The constructor now requires these new parameters.
  const BurdenRateSettingsScreen({
    super.key,
    required this.employeeNumberPrefixController,
    required this.nextEmployeeNumberController,
    required this.backupFrequencyController,
    required this.reportMonthsController,
    required this.settingsModel,
  });

  @override
  State<BurdenRateSettingsScreen> createState() => _BurdenRateSettingsScreenState();
}
// end class: BurdenRateSettingsScreen

// start class: _BurdenRateSettingsScreenState
class _BurdenRateSettingsScreenState extends State<BurdenRateSettingsScreen> {
  final _dbHelper = DatabaseHelperV2.instance;
  final TextEditingController _rateController = TextEditingController();

  // These controllers are for the calculator part only.
  final TextEditingController _overheadController = TextEditingController();
  final TextEditingController _wagesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _profitController = TextEditingController();

  double? _calculatedRate;

  // Removed _isLoading and _loadCurrentRate as the data is now passed in directly.

  // start method: initState
  @override
  void initState() {
    super.initState();
    // **** MODIFIED ****: Load the rate from the settings model passed by the parent.
    if (widget.settingsModel.companyHourlyRate != null) {
      _rateController.text = widget.settingsModel.companyHourlyRate!.toStringAsFixed(2);
    }
  }
  // end method: initState

  // start method: dispose
  @override
  void dispose() {
    _rateController.dispose();
    _overheadController.dispose();
    _wagesController.dispose();
    _hoursController.dispose();
    _profitController.dispose();
    super.dispose();
  }
  // end method: dispose

  // **** REFACTORED _saveRate METHOD - Direct database access ****
  Future<void> _saveRate(double rate) async {
    final db = await _dbHelper.database;

    // 1. Get the current values from the General tab's controllers.
    final generalSettings = widget.settingsModel.copyWith(
      employeeNumberPrefix: widget.employeeNumberPrefixController.text.isEmpty
          ? null
          : widget.employeeNumberPrefixController.text,
      nextEmployeeNumber: int.tryParse(widget.nextEmployeeNumberController.text),
      autoBackupReminderFrequency: int.tryParse(widget.backupFrequencyController.text) ?? 10,
      defaultReportMonths: int.tryParse(widget.reportMonthsController.text) ?? 3,
    );

    // 2. Create the final, fully updated settings object.
    // This includes the general settings from step 1 AND the new burden rate.
    final updatedSettings = generalSettings.copyWith(
      burdenRate: rate,
      companyHourlyRate: rate,
    );

    // 3. Save directly to database
    await db.update(
      'settings',
      updatedSettings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );

    // Notify listeners
    _dbHelper.notifyDatabaseChanged();

    // 4. Update UI.
    if (!mounted) return; // This is the fix
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Burden rate saved: \$${rate.toStringAsFixed(2)}/hour')),
    );

    // No need to set controller text here as it's already set by the user

  }
  // end method: _saveRate

  // start method: _calculateBurdenRate (No changes to this method)
  void _calculateBurdenRate() {
    final overhead = double.tryParse(_overheadController.text) ?? 0;
    final wages = double.tryParse(_wagesController.text) ?? 0;
    final hours = double.tryParse(_hoursController.text) ?? 0;
    final profit = double.tryParse(_profitController.text) ?? 0;

    if (hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid billable hours')),
      );
      return;
    }

    final totalCosts = overhead + wages;
    final profitAmount = totalCosts * (profit / 100);
    final totalWithProfit = totalCosts + profitAmount;
    final burdenRate = totalWithProfit / hours;

    setState(() {
      _calculatedRate = burdenRate;
    });
  }
  // end method: _calculateBurdenRate

  // start method: build
  @override
  Widget build(BuildContext context) {
    // No more _isLoading check needed
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ... The entire UI below this line has NO CHANGES ...
            // Manual Rate Entry Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual Rate Entry',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Default Company Hourly Rate',
                              prefixText: '\$',
                              suffixText: '/hour',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final rate = double.tryParse(_rateController.text);
                            if (rate != null && rate > 0) {
                              _saveRate(rate); // This now saves ALL settings correctly
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid rate')),
                              );
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Calculator Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Burden Rate Calculator',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _overheadController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Annual Overhead',
                              prefixText: '\$',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _wagesController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Annual Wages',
                              prefixText: '\$',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hoursController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Billable Hours/Year',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _profitController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Profit Margin',
                              suffixText: '%',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _calculateBurdenRate,
                          child: const Text('Calculate'),
                        ),
                        const SizedBox(width: 12),
                        if (_calculatedRate != null) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha((255 * 0.1).round()),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Calculated Rate: \$${_calculatedRate!.toStringAsFixed(2)}/hour',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  // The corrected TextButton
                                  TextButton(
                                    onPressed: () {
                                      // 1. Get the rate value first.
                                      final rateToSave = _calculatedRate!;
                                      _rateController.text = rateToSave.toStringAsFixed(2);
                                      _saveRate(rateToSave);
                                      setState(() {
                                        _calculatedRate = null;
                                      });
                                    },
                                    child: const Text('Use This Rate & Save'),
                                  ),

                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
// end method: build
}
// end class: _BurdenRateSettingsScreenState