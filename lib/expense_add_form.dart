// lib/expense_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:intl/intl.dart';

class ExpenseAddForm extends StatefulWidget {
  final List<Project> projects;
  final List<String> expenseCategories;
  final List<String> vehicleDesignations;
  final List<String> vendors;
  final Function(Material) onSubmit;

  const ExpenseAddForm({
    super.key,
    required this.projects,
    required this.expenseCategories,
    required this.vehicleDesignations,
    required this.vendors,
    required this.onSubmit,
  });

  @override
  State<ExpenseAddForm> createState() => _ExpenseAddFormState();
}

class _ExpenseAddFormState extends State<ExpenseAddForm> {
  // Form Key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _odometerReadingController = TextEditingController();

  // Selected values for dropdowns and date picker
  Project? _selectedProject;
  DateTime? _selectedPurchaseDate;
  String? _selectedExpenseCategory;
  String? _selectedVehicleDesignation;
  String? _selectedVendor;

  bool _isCompanyExpense = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _odometerReadingController.dispose();
    super.dispose();
  }

  Future<void> _selectPurchaseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPurchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedPurchaseDate) {
      setState(() {
        _selectedPurchaseDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newExpense = Material(
        projectId: _selectedProject!.id!,
        itemName: _itemNameController.text,
        cost: double.parse(_costController.text),
        purchaseDate: _selectedPurchaseDate ?? DateTime.now(),
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        expenseCategory: _selectedExpenseCategory,
        quantity: _quantityController.text.isNotEmpty ? double.parse(_quantityController.text) : null,
        odometerReading: _odometerReadingController.text.isNotEmpty ? double.parse(_odometerReadingController.text) : null,
        isCompanyExpense: _isCompanyExpense,
        vehicleDesignation: _selectedVehicleDesignation,
        vendorOrSubtrade: _selectedVendor,
      );
      widget.onSubmit(newExpense);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              // Project Dropdown
              DropdownButtonFormField<Project>(
                decoration: const InputDecoration(labelText: 'Select Project *'),
                value: _selectedProject,
                items: widget.projects.map((project) {
                  return DropdownMenuItem<Project>(
                    value: project,
                    child: Text(project.projectName),
                  );
                }).toList(),
                onChanged: (Project? newValue) {
                  setState(() {
                    _selectedProject = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a project' : null,
              ),
              const SizedBox(height: 16),

              // Item Name and Cost Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(labelText: 'Item Name *'),
                      validator: (value) => value!.isEmpty ? 'Please enter an item name' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Cost *',
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter a cost';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Purchase Date and Category Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectPurchaseDate(context),
                      child: Text(
                        _selectedPurchaseDate == null
                            ? 'Select Purchase Date *'
                            : DateFormat('MMM d, yyyy').format(_selectedPurchaseDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Category'),
                      value: _selectedExpenseCategory,
                      items: widget.expenseCategories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedExpenseCategory = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity and Description
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vehicle and Vendor
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Vehicle Designation'),
                      value: _selectedVehicleDesignation,
                      items: widget.vehicleDesignations.map((designation) {
                        return DropdownMenuItem<String>(
                          value: designation,
                          child: Text(designation),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedVehicleDesignation = newValue;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Vendor/Subtrade'),
                      value: _selectedVendor,
                      items: widget.vendors.map((vendor) {
                        return DropdownMenuItem<String>(
                          value: vendor,
                          child: Text(vendor),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedVendor = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Odometer Reading and Company Expense Checkbox
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _odometerReadingController,
                      decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isCompanyExpense,
                        onChanged: (bool? newValue) {
                          setState(() {
                            _isCompanyExpense = newValue ?? false;
                          });
                        },
                      ),
                      const Text('Company Expense'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('Add Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}