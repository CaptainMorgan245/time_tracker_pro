// employee_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/employee_repository.dart';

class AddEmployeeForm extends StatefulWidget {
  final List<Role> roles;
  final VoidCallback onEmployeeAdded;

  const AddEmployeeForm({
    super.key,
    required this.roles,
    required this.onEmployeeAdded,
  });

  @override
  State<AddEmployeeForm> createState() => _AddEmployeeFormState();
}

class _AddEmployeeFormState extends State<AddEmployeeForm> {
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final TextEditingController _nameController = TextEditingController();

  Role? _selectedRole;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final role = _selectedRole;

    if (name.isEmpty || role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and role are required')),
      );
      return;
    }

    final newEmployee = Employee(
      name: name,
      titleId: role.id,
    );

    setState(() => _isSubmitting = true);

    try {
      await _employeeRepo.insertEmployee(newEmployee);
      _nameController.clear();
      setState(() => _selectedRole = null);
      widget.onEmployeeAdded();
    } catch (e) {
      debugPrint('Error adding employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding employee: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validRoles = widget.roles.where((r) => r.id != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add New Employee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Employee Name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedRole?.id,
                items: validRoles.map((role) {
                  return DropdownMenuItem<int>(
                    value: role.id,
                    child: Text(role.name),
                  );
                }).toList(),
                onChanged: (int? selectedId) {
                  setState(() {
                    _selectedRole = validRoles.firstWhere((r) => r.id == selectedId);
                  });
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting ? const CircularProgressIndicator() : const Text('Add Employee'),
          ),
        ),
      ],
    );
  }
}