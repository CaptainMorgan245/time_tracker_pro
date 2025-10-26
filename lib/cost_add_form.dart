// lib/cost_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart' as app_models;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class ExpenseAddForm extends StatefulWidget {
  final List<app_models.Project> projects;
  final List<String> expenseCategories;
  final List<String> vehicleDesignations;
  final List<String> vendors;
  final Function(app_models.JobMaterials) onSubmit;

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

  // Controllers for text fields - REMOVED _itemNameController
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _odometerReadingController = TextEditingController();

  // Selected values for dropdowns and date picker
  app_models.Project? _selectedProject;
  DateTime? _selectedPurchaseDate;
  String? _selectedExpenseCategory;
  String? _selectedVehicleDesignation;
  String? _selectedVendor;

  bool _isCompanyExpense = false;

  @override
  void dispose() {
    // REMOVED _itemNameController.dispose();
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
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_formKey.currentState!.validate()) {
      final newExpense = app_models.JobMaterials(
        projectId: _selectedProject!.id!,
        itemName: '', // EMPTY since we removed the field
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
              DropdownButtonFormField<app_models.Project>(
                decoration: const InputDecoration(labelText: 'Select Project *'),
                value: _selectedProject,
                items: widget.projects.map((project) {
                  return DropdownMenuItem<app_models.Project>(
                    value: project,
                    child: Text(project.projectName),
                  );
                }).toList(),
                onChanged: (app_models.Project? newValue) {
                  setState(() {
                    _selectedProject = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a project' : null,
              ),
              const SizedBox(height: 16),

              // VENDOR + DATE + COST on one row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Vendor'),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectPurchaseDate(context),
                      child: Text(
                        _selectedPurchaseDate == null
                            ? 'Date *'
                            : DateFormat('MMM d').format(_selectedPurchaseDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Cost *',
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value!.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Row
              DropdownButtonFormField<String>(
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

              // Vehicle Designation
              DropdownButtonFormField<String>(
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