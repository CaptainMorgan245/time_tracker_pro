// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/role_repository.dart';
import 'package:time_tracker_pro/input_formatters.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/expenses_screen.dart';
// FIX: Using 'show' to explicitly define which widget comes from which file to prevent conflicts.
import 'package:time_tracker_pro/employee_list_screen.dart' show EmployeeListScreen;
import 'package:time_tracker_pro/employee_add_form.dart' show AddEmployeeForm;
import 'package:time_tracker_pro/widgets/app_setting_list_card.dart'; // For Roles List

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
  final RoleRepository _roleRepo = RoleRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  SettingsModel _settings = SettingsModel();
  final TextEditingController _employeeNumberPrefixController = TextEditingController();
  final TextEditingController _nextEmployeeNumberController = TextEditingController();
  final TextEditingController _roleNameController = TextEditingController();
  final TextEditingController _roleRateController = TextEditingController();

  bool _isLoadingRoles = true;
  bool _isLoadingEmployees = true;

  List<Role> _roles = [];
  List<Employee> _employees = [];

  // start method: initState
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }
  // end method: initState

  // start method: dispose
  @override
  void dispose() {
    _tabController.dispose();
    _employeeNumberPrefixController.dispose();
    _nextEmployeeNumberController.dispose();
    _roleNameController.dispose();
    _roleRateController.dispose();
    super.dispose();
  }
  // end method: dispose

  // start method: _loadData
  Future<void> _loadData() async {
    await _loadSettings();
    await _loadRoles();
    await _loadEmployees();
  }
  // end method: _loadData

  // start method: _loadSettings
  Future<void> _loadSettings() async {
    final loadedSettings = await _settingsService.loadSettings();
    setState(() {
      _settings = loadedSettings ?? SettingsModel();
      _employeeNumberPrefixController.text = _settings.employeeNumberPrefix ?? '';
      _nextEmployeeNumberController.text = (_settings.nextEmployeeNumber ?? 1).toString();
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
    );

    await _settingsService.saveSettings(settings);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings Saved!')),
    );
  }
  // end method: _saveSettings

  // start method: _loadRoles
  Future<void> _loadRoles() async {
    setState(() { _isLoadingRoles = true; });
    final roles = await _roleRepo.getRoles();
    setState(() {
      _roles = roles;
      _isLoadingRoles = false;
    });
  }
  // end method: _loadRoles

  // start method: _loadEmployees
  Future<void> _loadEmployees() async {
    setState(() { _isLoadingEmployees = true; });
    try {
      final employees = await _employeeRepo.getEmployees();
      setState(() {
        _employees = employees;
      });
    } catch (e) {
      debugPrint('Error loading employees: $e');
    } finally {
      setState(() {
        _isLoadingEmployees = false;
      });
    }
  }
  // end method: _loadEmployees

  // start method: _addRole
  Future<void> _addRole() async {
    if (_roleNameController.text.isNotEmpty) {
      // Dismiss keyboard before submitting
      FocusScope.of(context).unfocus();
      final newRole = Role(
        name: _roleNameController.text,
        standardRate: double.tryParse(_roleRateController.text) ?? 0.0,
      );
      await _roleRepo.insertRole(newRole);
      _roleNameController.clear();
      _roleRateController.clear();
      _loadRoles();
    }
  }
  // end method: _addRole

  // start method: _deleteRole
  Future<void> _deleteRole(int id) async {
    await _roleRepo.deleteRole(id);
    _loadRoles();
  }
  // end method: _deleteRole

  // start method: _showEditRoleDialog
  Future<void> _showEditRoleDialog(Role role) async {
    final nameController = TextEditingController(text: role.name);
    final rateController = TextEditingController(text: role.standardRate.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                inputFormatters: [CapitalizeEachWordInputFormatter()],
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'Standard Rate/hr'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Safe Deletion UX enforced here
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _deleteRole(role.id!);
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final updatedRole = role.copyWith(
                    name: nameController.text,
                    standardRate: double.tryParse(rateController.text) ?? 0.0,
                  );
                  await _roleRepo.updateRole(updatedRole);
                  _loadRoles();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // end method: _showEditRoleDialog

  // start method: _buildRolesList
  Widget _buildRolesList() {
    if (_isLoadingRoles) {
      return const Center(child: CircularProgressIndicator());
    }

    // List of strings is required for AppSettingListCard
    final rolesData = _roles.map((role) =>
    '${role.name} (\$${role.standardRate.toStringAsFixed(2)} / hr)'
    ).toList();

    return AppSettingListCard(
      // FIX: Title is removed here, as the component allows it to be empty.
      title: '',
      items: rolesData,
      // The onEdit callback needs to extract the Role object based on index
      onEdit: (index) => _showEditRoleDialog(_roles[index]),
    );
  }
  // end method: _buildRolesList

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
          // Tab 1: General & Reports Settings (Kept simple)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'General Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _employeeNumberPrefixController,
                          decoration: const InputDecoration(labelText: 'Employee Number Prefix'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nextEmployeeNumberController,
                          decoration: const InputDecoration(labelText: 'Next Employee Number'),
                          keyboardType: TextInputType.number,
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

          // Tab 2: Personnel Tab Content (Employees and Roles) - FIXED LAYOUT
          Column(
            children: [
              // Top Section: Add Employee & Add Role Forms (Fixed Height)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Add Employee Form
                    Flexible(
                      child: AddEmployeeForm(
                        roles: _roles,
                        onEmployeeAdded: _loadEmployees,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Manage Company Roles Form
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Role',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _roleNameController,
                                          inputFormatters: [CapitalizeEachWordInputFormatter()],
                                          decoration: const InputDecoration(labelText: 'Role Name'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _roleRateController,
                                          decoration: const InputDecoration(labelText: 'Standard Rate/hr'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton(
                                      onPressed: _addRole,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Add Role'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Divider between forms and lists
              const Divider(height: 1, thickness: 1),

              // Bottom Section: Employee and Roles Lists (INDIVIDUALLY SCROLLING)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee List
                      Expanded(
                        child: EmployeeListScreen(
                          employees: _employees,
                          roles: _roles,
                          isLoading: _isLoadingEmployees,
                          onUpdate: _loadEmployees,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Roles List
                      Expanded(
                        child: _buildRolesList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Tab 3-5: Other Tabs
          const ExpensesScreen(),
          const Center(child: Text('Email settings coming soon...')),
          const Center(child: Text('Burden Rate settings coming soon...')),
        ],
      ),
    );
  }
// end method: build
}
// end class: _SettingsScreenState
