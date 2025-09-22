// settings_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/employee_list_screen.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/role_repository.dart';
import 'package:time_tracker_pro/input_formatters.dart';
import 'package:time_tracker_pro/employee_add_form.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/expenses_screen.dart'; // New import

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _employeeNumberPrefixController.dispose();
    _nextEmployeeNumberController.dispose();
    _roleNameController.dispose();
    _roleRateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadSettings();
    await _loadRoles();
    await _loadEmployees();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await _settingsService.loadSettings();
    setState(() {
      _settings = loadedSettings ?? SettingsModel();
      _employeeNumberPrefixController.text = _settings.employeeNumberPrefix ?? '';
      _nextEmployeeNumberController.text = (_settings.nextEmployeeNumber ?? 1).toString();
    });
  }

  Future<void> _saveSettings() async {
    final settings = SettingsModel(
      employeeNumberPrefix: _employeeNumberPrefixController.text.isEmpty
          ? null
          : _employeeNumberPrefixController.text,
      nextEmployeeNumber: int.tryParse(_nextEmployeeNumberController.text),
    );

    await _settingsService.saveSettings(settings);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  Future<void> _loadRoles() async {
    setState(() { _isLoadingRoles = true; });
    final roles = await _roleRepo.getRoles();
    setState(() {
      _roles = roles;
      _isLoadingRoles = false;
    });
  }

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

  Future<void> _addRole() async {
    if (_roleNameController.text.isNotEmpty) {
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

  Future<void> _deleteRole(int id) async {
    await _roleRepo.deleteRole(id);
    _loadRoles();
  }

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
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'General & Reports Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: 250,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: AddEmployeeForm(
                          roles: _roles,
                          onEmployeeAdded: _loadEmployees,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manage Company Roles',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            TextFormField(
                              controller: _roleNameController,
                              inputFormatters: [CapitalizeEachWordInputFormatter()],
                              decoration: const InputDecoration(labelText: 'Role Name'),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _roleRateController,
                              decoration: const InputDecoration(labelText: 'Standard Rate/hr'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addRole,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Add Role'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: EmployeeListScreen(
                        employees: _employees,
                        roles: _roles,
                        isLoading: _isLoadingEmployees,
                        onUpdate: _loadEmployees,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Roles',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            _isLoadingRoles
                                ? const CircularProgressIndicator()
                                : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _roles.length,
                              itemBuilder: (context, index) {
                                final role = _roles[index];
                                return ListTile(
                                  title: Text(role.name),
                                  subtitle: Text('\$${role.standardRate} / hr'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditRoleDialog(role),
                                  ),
                                );
                              },
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

          const ExpensesScreen(),
          const Center(child: Text('Email settings coming soon...')),
          const Center(child: Text('Burden Rate settings coming soon...')),
        ],
      ),
    );
  }
}