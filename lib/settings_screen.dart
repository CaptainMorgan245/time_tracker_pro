// lib/settings_screen.dart

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/expenses_screen.dart';
import 'package:time_tracker_pro/personnel_screen.dart';
import 'package:time_tracker_pro/burden_rate_settings_screen.dart';
import 'package:time_tracker_pro/help_support_screen.dart';
import 'package:time_tracker_pro/company_tax_settings_tab.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/dashboard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dbHelper = AppDatabase.instance;

  SettingsModel _settings = SettingsModel();
  CompanySettings _companySettings = CompanySettings();

  // App Settings Controllers
  final TextEditingController employeeNumberPrefixController = TextEditingController();
  final TextEditingController nextEmployeeNumberController = TextEditingController();
  final TextEditingController backupFrequencyController = TextEditingController();
  final TextEditingController reportMonthsController = TextEditingController();
  final TextEditingController expenseMarkupPercentageController = TextEditingController();

  // Company Settings Controllers
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController companyAddressController = TextEditingController();
  final TextEditingController companyCityController = TextEditingController();
  final TextEditingController companyProvinceController = TextEditingController();
  final TextEditingController companyPostalCodeController = TextEditingController();
  final TextEditingController companyPhoneController = TextEditingController();
  final TextEditingController companyEmailController = TextEditingController();
  final TextEditingController tax1NameController = TextEditingController();
  final TextEditingController tax1RateController = TextEditingController();
  final TextEditingController tax1RegController = TextEditingController();
  final TextEditingController tax2NameController = TextEditingController();
  final TextEditingController tax2RateController = TextEditingController();
  final TextEditingController tax2RegController = TextEditingController();
  final TextEditingController termsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
    _loadCompanySettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    employeeNumberPrefixController.dispose();
    nextEmployeeNumberController.dispose();
    backupFrequencyController.dispose();
    reportMonthsController.dispose();
    expenseMarkupPercentageController.dispose();

    companyNameController.dispose();
    companyAddressController.dispose();
    companyCityController.dispose();
    companyProvinceController.dispose();
    companyPostalCodeController.dispose();
    companyPhoneController.dispose();
    companyEmailController.dispose();
    tax1NameController.dispose();
    tax1RateController.dispose();
    tax1RegController.dispose();
    tax2NameController.dispose();
    tax2RateController.dispose();
    tax2RegController.dispose();
    termsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final rows = await _dbHelper.customSelect(
      'SELECT * FROM settings WHERE id = 1',
    ).get();
    final loadedSettings = rows.isNotEmpty ? SettingsModel.fromMap(rows.first.data) : SettingsModel();

    setState(() {
      _settings = loadedSettings;
      employeeNumberPrefixController.text = _settings.employeeNumberPrefix ?? '';
      nextEmployeeNumberController.text = (_settings.nextEmployeeNumber ?? 1).toString();
      backupFrequencyController.text = _settings.autoBackupReminderFrequency.toString();
      reportMonthsController.text = _settings.defaultReportMonths.toString();
      expenseMarkupPercentageController.text = _settings.expenseMarkupPercentage.toStringAsFixed(2);
    });
  }

  Future<void> _loadCompanySettings() async {
    final loadedCompany = await _dbHelper.getCompanySettings();
    setState(() {
      _companySettings = loadedCompany;
      companyNameController.text = _companySettings.companyName ?? '';
      companyAddressController.text = _companySettings.companyAddress ?? '';
      companyCityController.text = _companySettings.companyCity ?? '';
      companyProvinceController.text = _companySettings.companyProvince ?? '';
      companyPostalCodeController.text = _companySettings.companyPostalCode ?? '';
      companyPhoneController.text = _companySettings.companyPhone ?? '';
      companyEmailController.text = _companySettings.companyEmail ?? '';
      tax1NameController.text = _companySettings.defaultTax1Name;
      tax1RateController.text = (_companySettings.defaultTax1Rate * 100).toStringAsFixed(2);
      tax1RegController.text = _companySettings.defaultTax1RegistrationNumber ?? '';
      tax2NameController.text = _companySettings.defaultTax2Name ?? '';
      tax2RateController.text = _companySettings.defaultTax2Rate != null 
          ? (_companySettings.defaultTax2Rate! * 100).toStringAsFixed(2) 
          : '';
      tax2RegController.text = _companySettings.defaultTax2RegistrationNumber ?? '';
      termsController.text = _companySettings.defaultTerms;
    });
  }

  Future<void> _saveSettings({double? currentBurdenRate}) async {
    // 1. Save App Settings
    final settings = _settings.copyWith(
      employeeNumberPrefix: employeeNumberPrefixController.text.isEmpty ? null : employeeNumberPrefixController.text,
      nextEmployeeNumber: int.tryParse(nextEmployeeNumberController.text),
      autoBackupReminderFrequency: int.tryParse(backupFrequencyController.text) ?? 10,
      defaultReportMonths: int.tryParse(reportMonthsController.text) ?? 3,
      expenseMarkupPercentage: double.tryParse(expenseMarkupPercentageController.text) ?? 0.0,
      companyHourlyRate: currentBurdenRate ?? _settings.companyHourlyRate,
      setupCompleted: true,
    );

    await _dbHelper.customUpdate(
      'UPDATE settings SET employee_number_prefix=?, next_employee_number=?, auto_backup_reminder_frequency=?, default_report_months=?, expense_markup_percentage=?, company_hourly_rate=?, setup_completed=? WHERE id=1',
      variables: [
        Variable(settings.employeeNumberPrefix),
        Variable(settings.nextEmployeeNumber),
        Variable.withInt(settings.autoBackupReminderFrequency),
        Variable.withInt(settings.defaultReportMonths),
        Variable.withReal(settings.expenseMarkupPercentage),
        Variable(settings.companyHourlyRate),
        Variable.withInt(1),
      ],
      updates: {},
    );

    // 2. Save Company Settings
    final double tax1Rate = (double.tryParse(tax1RateController.text) ?? 0.0) / 100.0;
    final double? tax2RateStr = double.tryParse(tax2RateController.text);
    final double? tax2Rate = tax2RateStr != null ? tax2RateStr / 100.0 : null;

    final updatedCompany = _companySettings.copyWith(
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyCity: companyCityController.text,
      companyProvince: companyProvinceController.text,
      companyPostalCode: companyPostalCodeController.text,
      companyPhone: companyPhoneController.text,
      companyEmail: companyEmailController.text,
      defaultTax1Name: tax1NameController.text,
      defaultTax1Rate: tax1Rate,
      defaultTax1RegistrationNumber: tax1RegController.text,
      defaultTax2Name: tax2NameController.text,
      defaultTax2Rate: tax2Rate,
      defaultTax2RegistrationNumber: tax2RegController.text,
      defaultTerms: termsController.text,
    );

    await _dbHelper.updateCompanySettings(updatedCompany);
    _dbHelper.notifyDatabaseChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All Settings Saved!')),
    );

    // Navigate to Dashboard and clear stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

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
            Tab(text: 'Company & Tax'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: General & Reports
          _buildGeneralTab(),
          const PersonnelScreen(),
          const ExpensesScreen(),
          const HelpSupportScreen(),
          BurdenRateSettingsScreen(
            employeeNumberPrefixController: employeeNumberPrefixController,
            nextEmployeeNumberController: nextEmployeeNumberController,
            backupFrequencyController: backupFrequencyController,
            reportMonthsController: reportMonthsController,
            settingsModel: _settings,
          ),
          // Tab 6: Company & Tax
          CompanyTaxSettingsTab(
            companyNameController: companyNameController,
            companyAddressController: companyAddressController,
            companyCityController: companyCityController,
            companyProvinceController: companyProvinceController,
            companyPostalCodeController: companyPostalCodeController,
            companyPhoneController: companyPhoneController,
            companyEmailController: companyEmailController,
            tax1NameController: tax1NameController,
            tax1RateController: tax1RateController,
            tax1RegController: tax1RegController,
            tax2NameController: tax2NameController,
            tax2RateController: tax2RateController,
            tax2RegController: tax2RegController,
            termsController: termsController,
            onSave: _saveSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Employee Numbers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 18),
                        onPressed: () => _showHelpDialog('Employee Numbers', 'Prefix and sequential numbering for staff.'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: employeeNumberPrefixController, decoration: const InputDecoration(labelText: 'Prefix'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: nextEmployeeNumberController, decoration: const InputDecoration(labelText: 'Next #'), keyboardType: TextInputType.number)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time & Measurement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: _settings.timeRoundingInterval,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('No Rounding')),
                            DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                            DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                          ],
                          onChanged: (val) => setState(() => _settings = _settings.copyWith(timeRoundingInterval: val!)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _settings.measurementSystem,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'metric', child: Text('Metric')),
                            DropdownMenuItem(value: 'imperial', child: Text('Imperial')),
                          ],
                          onChanged: (val) => setState(() => _settings = _settings.copyWith(measurementSystem: val!)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup & Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: backupFrequencyController, decoration: const InputDecoration(labelText: 'Backup Freq'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: reportMonthsController, decoration: const InputDecoration(labelText: 'Report Months'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: expenseMarkupPercentageController, decoration: const InputDecoration(labelText: 'Expense Markup %'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
            child: const Text('Save All Settings'),
          ),
        ],
      ),
    );
  }
}
