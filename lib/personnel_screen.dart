// lib/personnel_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/role_repository.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/employee_add_form.dart';
import 'package:time_tracker_pro/employee_list_screen.dart';
import 'package:time_tracker_pro/widgets/app_setting_list_card.dart';

// start class: PersonnelScreen
class PersonnelScreen extends StatefulWidget {
  // start method: constructor
  const PersonnelScreen({super.key});
  // end method: constructor

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}
// end class: PersonnelScreen

// start class: _PersonnelScreenState
class _PersonnelScreenState extends State<PersonnelScreen> {
  final RoleRepository _roleRepo = RoleRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();

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
    _loadData();
  }
  // end method: initState

  // start method: dispose
  @override
  void dispose() {
    _roleNameController.dispose();
    _roleRateController.dispose();
    super.dispose();
  }
  // end method: dispose

  // start method: _loadData
  Future<void> _loadData() async {
    await _loadRoles();
    await _loadEmployees();
  }
  // end method: _loadData

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
                textCapitalization: TextCapitalization.words,
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
  // end method: _showEditRoleDialog

  // start method: _buildRolesList
  Widget _buildRolesList() {
    if (_isLoadingRoles) {
      return const Center(child: CircularProgressIndicator());
    }

    final rolesData = _roles.map((role) =>
    '${role.name} (\$${role.standardRate.toStringAsFixed(2)} / hr)'
    ).toList();

    return AppSettingListCard(
      title: '',
      items: rolesData,
      onEdit: (index) => _showEditRoleDialog(_roles[index]),
    );
  }
  // end method: _buildRolesList

  // start method: build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Top Section: Add Employee & Add Role Forms
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: Add Employee Form
                  Flexible(
                    child: AddEmployeeForm(
                      roles: _roles,
                      onEmployeeAdded: _loadEmployees,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: Add Role Form
                  Flexible(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _roleNameController,
                                    textCapitalization: TextCapitalization.words,
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
                            const SizedBox(height: 12),
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
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Bottom Section: Employee and Roles Lists
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
    );
  }
// end method: build
}
// end class: _PersonnelScreenState