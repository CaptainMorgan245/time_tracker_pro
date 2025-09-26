// lib/employee_list_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/input_formatters.dart';
import 'package:flutter/services.dart';

// start class: EmployeeListScreen
class EmployeeListScreen extends StatefulWidget {
  final List<Role> roles;
  final List<Employee> employees;
  final bool isLoading;
  final VoidCallback onUpdate;

  const EmployeeListScreen({
    super.key,
    required this.roles,
    required this.employees,
    required this.isLoading,
    required this.onUpdate,
  });

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}
// end class: EmployeeListScreen

// start class: _EmployeeListScreenState
class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  @override
  void initState() {
    super.initState();
  }

  // start method: _loadEmployees
  Future<void> _loadEmployees() async {
    widget.onUpdate();
  }
  // end method: _loadEmployees

  // start method: _addEmployee
  Future<void> _addEmployee(String name, int? roleId) async {
    final newEntry = Employee(
      name: name,
      titleId: roleId,
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

  // start method: _deleteEmployee
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

  // start method: _showEditDialog (Unified Dialog)
  Future<void> _showEditDialog(Employee? employee) async {
    final isNew = employee == null;
    final nameController = TextEditingController(text: employee?.name ?? '');
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
                inputFormatters: [CapitalizeEachWordInputFormatter()],
                decoration: const InputDecoration(labelText: 'Employee Name'),
              ),
              if (!isNew)
                TextField(
                  controller: TextEditingController(text: employeeNumber),
                  decoration: const InputDecoration(labelText: 'Employee Number'),
                  readOnly: true,
                ),
              const SizedBox(height: 16),
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
                  final updatedEmployee = employee!.copyWith(isDeleted: !isDeleted);
                  _updateEmployee(updatedEmployee);
                  Navigator.of(context).pop();
                },
              ),
            ElevatedButton(
              child: Text(isNew ? 'Add' : 'Save'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  if (isNew) {
                    _addEmployee(nameController.text, selectedRole?.id);
                  } else {
                    final updatedEmployee = employee!.copyWith(
                      name: nameController.text,
                      titleId: selectedRole?.id,
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

  @override
  Widget build(BuildContext context) {
    // Filter out deleted employees for the primary view
    final activeEmployees = widget.employees.where((e) => !e.isDeleted).toList();
    final theme = Theme.of(context);

    return widget.isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [


          // FIX 5: Use a SingleChildScrollView with ListView.builder for clean, scrolling lists
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeEmployees.length,
            itemBuilder: (context, index) {
              final employee = activeEmployees[index];
              final role = widget.roles.firstWhere(
                    (r) => r.id == employee.titleId,
                orElse: () => Role(name: 'N/A'),
              );
              return Card(
                color: theme.cardColor,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  title: Text(employee.name),
                  subtitle: Text('Role: ${role.name} | Number: ${employee.employeeNumber ?? 'N/A'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditDialog(employee),
                  ),
                  onTap: () => _showEditDialog(employee),
                ),
              );
            },
          ),

          // Display Deleted Employees separately
          if (widget.employees.any((e) => e.isDeleted)) ...[
            const SizedBox(height: 24),
            const Text('Inactive/Deleted Employees',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.employees.where((e) => e.isDeleted).length,
              itemBuilder: (context, index) {
                final employee = widget.employees.where((e) => e.isDeleted).toList()[index];
                final role = widget.roles.firstWhere(
                      (r) => r.id == employee.titleId,
                  orElse: () => Role(name: 'N/A'),
                );
                return Card(
                  color: Colors.grey[200],
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text('${employee.name} (INACTIVE)', style: const TextStyle(fontStyle: FontStyle.italic)),
                    subtitle: Text('Role: ${role.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditDialog(employee),
                    ),
                    onTap: () => _showEditDialog(employee),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
// end class: _EmployeeListScreenState