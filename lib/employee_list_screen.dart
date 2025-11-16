// lib/employee_list_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/employee_repository.dart';

// start class: EmployeeListScreen
class EmployeeListScreen extends StatefulWidget {
  final List<Role> roles;
  final List<Employee> employees;
  final bool isLoading;
  final VoidCallback onUpdate;

  // start method: constructor
  const EmployeeListScreen({
    super.key,
    required this.roles,
    required this.employees,
    required this.isLoading,
    required this.onUpdate,
  });
  // end method: constructor

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}
// end class: EmployeeListScreen

// start class: _EmployeeListScreenState
class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  // start method: initState
  @override
  void initState() {
    super.initState();
  }
  // end method: initState

  // start method: _loadEmployees
  Future<void> _loadEmployees() async {
    widget.onUpdate();
  }
  // end method: _loadEmployees

  // start method: _addEmployee
  Future<void> _addEmployee(String name, int? roleId, double? hourlyRate) async {
    final newEntry = Employee(
      name: name,
      titleId: roleId,
      hourlyRate: hourlyRate,
    );
    await _employeeRepo.insertEmployee(newEntry);
    _loadEmployees();
  }
  // end method: _addEmployee

  // start method: _updateEmployee
  Future<void> _updateEmployee(Employee employee) async {
    await _employeeRepo.updateEmployee(employee);
    _loadEmployees();
  }
  // end method: _updateEmployee

  /*/ start method: _deleteEmployee
  Future<void> _deleteEmployee(int id) async {
    final employee = widget.employees.firstWhere((e) => e.id == id);
    if (!employee.isDeleted) {
      final deletedEmployee = employee.copyWith(isDeleted: true);
      await _employeeRepo.updateEmployee(deletedEmployee);
    }
    _loadEmployees();
  }
  // end method: _deleteEmployee

  // start method: _showAddEmployeeDialog
  Future<void> _showAddEmployeeDialog() async {
    await _showEditDialog(null);
  }
  // end method: _showAddEmployeeDialog
*/
  // start method: _showEditDialog (Unified Dialog)
  Future<void> _showEditDialog(Employee? employee) async {
    final isNew = employee == null;
    final nameController = TextEditingController(text: employee?.name ?? '');
    final hourlyRateController = TextEditingController(
        text: employee?.hourlyRate?.toString() ?? ''
    );
    final employeeNumber = employee?.employeeNumber ?? 'Not Assigned';
    final isDeleted = employee?.isDeleted ?? false;
    Role? selectedRole = employee != null
        ? widget.roles.firstWhere((role) => role.id == employee.titleId, orElse: () => widget.roles.first)
        : null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Add New Employee' : 'Edit Employee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Employee Name'),
              ),
              const SizedBox(height: 16),
              if (!isNew)
                TextField(
                  controller: TextEditingController(text: employeeNumber),
                  decoration: const InputDecoration(labelText: 'Employee Number'),
                  readOnly: true,
                ),
              if (!isNew) const SizedBox(height: 16),
              DropdownButtonFormField<Role?>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Select Role'),
                items: [
                  const DropdownMenuItem<Role?>(value: null, child: Text('No Role')),
                  ...widget.roles.map((role) {
                    return DropdownMenuItem<Role?>(
                      value: role,
                      child: Text(role.name),
                    );
                  }).toList(),
                ],
                onChanged: (Role? newValue) {
                  selectedRole = newValue;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hourlyRateController,
                decoration: const InputDecoration(labelText: 'Hourly Rate'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (!isNew)
              TextButton(
                child: Text(isDeleted ? 'Activate' : 'Deactivate',
                    style: TextStyle(color: isDeleted ? Colors.green : Colors.red)),
                onPressed: () {
                  final updatedEmployee = employee.copyWith(isDeleted: !isDeleted);
                  _updateEmployee(updatedEmployee);
                  Navigator.of(context).pop();
                },
              ),
            ElevatedButton(
              child: Text(isNew ? 'Add' : 'Save'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final parsedRate = double.tryParse(hourlyRateController.text);
                  if (isNew) {
                    _addEmployee(nameController.text, selectedRole?.id, parsedRate);
                  } else {
                    final updatedEmployee = employee.copyWith(
                      name: nameController.text,
                      titleId: selectedRole?.id,
                      hourlyRate: parsedRate,
                    );
                    _updateEmployee(updatedEmployee);
                  }
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // end method: _showEditDialog

  // start method: _buildEmployeeList
  Widget _buildEmployeeList(List<Employee> list, Color color, {bool inactive = false}) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inactive)
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text('Inactive Employees', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final employee = list[index];
            final role = widget.roles.firstWhere(
                  (r) => r.id == employee.titleId,
              orElse: () => Role(name: 'N/A'),
            );
            // FIX: Removed individual Card wrappers to enforce single-card look
            return ListTile(
              title: Text(employee.name,
                  style: TextStyle(fontStyle: inactive ? FontStyle.italic : FontStyle.normal, color: color)),
              subtitle: Text('Role: ${role.name} | Number: ${employee.employeeNumber ?? 'N/A'}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditDialog(employee),
              ),
              onTap: () => _showEditDialog(employee),
            );
          },
        ),
      ],
    );
  }
  // end method: _buildEmployeeList

  // start method: build
  @override
  Widget build(BuildContext context) {
    final activeEmployees = widget.employees.where((e) => !e.isDeleted).toList();
    final inactiveEmployees = widget.employees.where((e) => e.isDeleted).toList();

    return widget.isLoading
        ? const Center(child: CircularProgressIndicator())
    // FIX: Wrapping the entire output in a single Card
        : Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmployeeList(activeEmployees, Colors.black),

              if (inactiveEmployees.isNotEmpty) ...[
                const Divider(),
                _buildEmployeeList(inactiveEmployees, Colors.grey, inactive: true),
              ]
            ],
          ),
        ),
      ),
    );
  }
// end method: build
}
// end class: _EmployeeListScreenState