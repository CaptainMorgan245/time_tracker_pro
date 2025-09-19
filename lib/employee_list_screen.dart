// employee_list_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/employee_repository.dart';
import 'package:time_tracker_pro/input_formatters.dart';

// start class: EmployeeListScreen
class EmployeeListScreen extends StatefulWidget {
  final List<Employee> employees;
  final List<Role> roles;
  final bool isLoading;
  final VoidCallback onUpdate;

  const EmployeeListScreen({
    super.key,
    required this.employees,
    required this.roles,
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

  // start method: _updateEmployee
  Future<void> _updateEmployee(Employee employee) async {
    await _employeeRepo.updateEmployee(employee);
    widget.onUpdate();
  }
  // end method: _updateEmployee

  // start method: _deleteEmployee
  Future<void> _deleteEmployee(int id) async {
    await _employeeRepo.deleteEmployee(id);
    widget.onUpdate();
  }
  // end method: _deleteEmployee

  String _getRoleName(int? roleId) {
    if (roleId == null) {
      return 'N/A';
    }
    try {
      final role = widget.roles.firstWhere((r) => r.id == roleId);
      return role.name;
    } catch (e) {
      return 'Unknown Role';
    }
  }

  // start method: _showEditEmployeeDialog
  Future<void> _showEditEmployeeDialog(Employee employee) async {
    final nameController = TextEditingController(text: employee.name);
    final employeeNumberController = TextEditingController(text: employee.employeeNumber);
    final isDeleted = employee.isDeleted;
    Role? selectedRole = widget.roles.firstWhere(
            (role) => role.id == employee.titleId,
        orElse: () => widget.roles.first
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Employee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                inputFormatters: [CapitalizeEachWordInputFormatter()],
                decoration: const InputDecoration(labelText: 'Employee Name'),
              ),
              TextField(
                controller: employeeNumberController,
                decoration: const InputDecoration(labelText: 'Employee Number'),
                readOnly: true, // This field is now read-only
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Role>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Select Role'),
                items: widget.roles.map((role) {
                  return DropdownMenuItem<Role>(
                    value: role,
                    child: Text(role.name),
                  );
                }).toList(),
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
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _deleteEmployee(employee.id!);
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final updatedEmployee = employee.copyWith(
                    id: employee.id,
                    name: nameController.text,
                    employeeNumber: employee.employeeNumber,
                    titleId: selectedRole?.id,
                    isDeleted: employee.isDeleted,
                  );
                  _updateEmployee(updatedEmployee);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // end method: _showEditEmployeeDialog

  @override
  Widget build(BuildContext context) {
    return widget.isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Number', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: widget.employees.map((employee) {
            final role = widget.roles.firstWhere(
                  (r) => r.id == employee.titleId,
              orElse: () => Role(name: 'N/A'),
            );
            return DataRow(
              cells: [
                DataCell(Text(employee.name)),
                DataCell(Text(employee.employeeNumber ?? 'N/A')),
                DataCell(Text(role.name)),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditEmployeeDialog(employee),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}