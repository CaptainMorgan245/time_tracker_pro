// lib/burden_rate_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/settings_model.dart';

// start class: BurdenRateSettingsScreen
class BurdenRateSettingsScreen extends StatefulWidget {
  const BurdenRateSettingsScreen({super.key});

  @override
  State<BurdenRateSettingsScreen> createState() => _BurdenRateSettingsScreenState();
}
// end class: BurdenRateSettingsScreen

// start class: _BurdenRateSettingsScreenState
class _BurdenRateSettingsScreenState extends State<BurdenRateSettingsScreen> {
  final SettingsService _settingsService = SettingsService.instance;
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _overheadController = TextEditingController();
  final TextEditingController _wagesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _profitController = TextEditingController();

  double? _calculatedRate;
  bool _isLoading = true;

  // start method: initState
  @override
  void initState() {
    super.initState();
    _loadCurrentRate();
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

  // start method: _loadCurrentRate
  Future<void> _loadCurrentRate() async {
    final settings = await _settingsService.loadSettings();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (settings != null && settings.companyHourlyRate != null) {
          _rateController.text = settings.companyHourlyRate!.toStringAsFixed(2);
        }
      });
    }
  }
  // end method: _loadCurrentRate

  // start method: _saveRate
  Future<void> _saveRate(double rate) async {
    final settings = await _settingsService.loadSettings() ?? SettingsModel();
    final updatedSettings = settings.copyWith(companyHourlyRate: rate);

    await _settingsService.saveSettings(updatedSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Burden rate saved: \$${rate.toStringAsFixed(2)}/hour')),
      );
      setState(() {
        _rateController.text = rate.toStringAsFixed(2);
      });
    }
  }
  // end method: _saveRate

  // start method: _calculateBurdenRate
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                              _saveRate(rate);
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
                                color: Colors.green.withOpacity(0.1),
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
                                  TextButton(
                                    onPressed: () => _saveRate(_calculatedRate!),
                                    child: const Text('Use This Rate'),
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