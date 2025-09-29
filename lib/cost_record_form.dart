// lib/cost_record_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/input_formatters.dart';

// Public state class is defined in the file scope
class CostRecordFormState extends State<CostRecordForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _odometerReadingController = TextEditingController();
  final TextEditingController _baseQuantityController = TextEditingController();

  Project? _selectedProject;
  DateTime _selectedPurchaseDate = DateTime.now();
  String? _selectedExpenseCategory;
  String? _selectedVendorOrSubtrade; // <--- CRITICAL FIX: ENSURING DECLARATION
  String? _selectedVehicleDesignation;
  // String? _selectedUnit is removed as per earlier request

  // IMPORTANT: Internal Company Project ID
  static const int _internalProjectId = 0;

  bool _isCompanyExpense = false;
  bool _isFuelCategory = false;

  // State for the project filter toggle (NOW A CHECKBOX)
  bool _showCompletedProjects = false;

  // Track the ID of the expense being edited
  int? _editingExpenseId;

  // Utility method to get the Internal Project object
  Project? _getInternalProject() {
    return widget.availableProjects.cast<Project?>().firstWhere(
          (p) => p?.id == _internalProjectId,
      orElse: () => null,
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize _selectedVendorOrSubtrade to null, same as other selection fields.
    // This is safe even if it was declared above.
    _selectedVendorOrSubtrade = null;

    if (widget.isEditing) {
      _selectedProject = widget.availableProjects.cast<Project?>().firstWhere(
            (p) => p?.projectName == 'Internal Company Project',
        orElse: () => widget.availableProjects.isNotEmpty
            ? widget.availableProjects.first
            : null,
      );
    } else {
      _selectedProject = null;
    }
  }

  @override
  void didUpdateWidget(covariant CostRecordForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableProjects.isNotEmpty && _selectedProject == null && !oldWidget.isEditing && widget.isEditing) {
      _selectedProject = widget.availableProjects.firstWhere(
            (p) => p.projectName == 'Internal Company Project',
        orElse: () => widget.availableProjects.first,
      );
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _odometerReadingController.dispose();
    _baseQuantityController.dispose();
    super.dispose();
  }

  void forceRebuild() {
    setState(() {});
  }

  // start method: populateForm
  void populateForm(JobMaterials expense) {
    setState(() {
      _editingExpenseId = expense.id;
      _itemNameController.text = expense.itemName;
      _costController.text = expense.cost.toStringAsFixed(2);
      _descriptionController.text = expense.description ?? '';
      _quantityController.text = expense.quantity?.toStringAsFixed(2) ?? '';
      _odometerReadingController.text = expense.odometerReading?.toStringAsFixed(0) ?? '';
      _baseQuantityController.text = expense.baseQuantity?.toStringAsFixed(2) ?? '';
      _selectedPurchaseDate = expense.purchaseDate;
      _isCompanyExpense = expense.isCompanyExpense;

      _selectedExpenseCategory = expense.expenseCategory;
      _isFuelCategory = expense.expenseCategory == 'Fuel';

      _selectedVehicleDesignation = expense.vehicleDesignation;
      // FIX: Populate the dedicated Vendor field
      _selectedVendorOrSubtrade = expense.vendorOrSubtrade;

      _selectedProject = widget.availableProjects.cast<Project?>().firstWhere(
            (p) => p?.id == expense.projectId,
        orElse: () => null,
      );
    });
  }
  // end method: populateForm

  // start method: resetForm
  void resetForm() {
    _formKey.currentState?.reset();
    _itemNameController.clear();
    _costController.clear();
    _descriptionController.clear();
    _quantityController.clear();
    _odometerReadingController.clear();
    _baseQuantityController.clear();

    setState(() {
      _editingExpenseId = null;
      _selectedPurchaseDate = DateTime.now();
      _isCompanyExpense = false;
      _isFuelCategory = false;
      _selectedExpenseCategory = null;
      _selectedVehicleDesignation = null;
      // FIX: Reset the dedicated Vendor field
      _selectedVendorOrSubtrade = null;
      _selectedProject = null;
    });
  }
  // end method: resetForm

  // start method: _selectPurchaseDate
  Future<void> _selectPurchaseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPurchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedPurchaseDate) {
      setState(() {
        _selectedPurchaseDate = picked;
      });
    }
  }
  // end method: _selectPurchaseDate

  // start method: _submitForm
  void _submitForm() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_isCompanyExpense || _formKey.currentState!.validate()) {

      final int submissionProjectId = _isCompanyExpense
          ? _internalProjectId
          : _selectedProject!.id!;

      // Placeholder unit for submission, assumed to be set globally later.
      const String assumedUnit = 'Liters';

      final newExpense = JobMaterials(
        id: _editingExpenseId,
        projectId: submissionProjectId,
        itemName: _itemNameController.text.isEmpty ? 'N/A' : _itemNameController.text,
        cost: double.parse(_costController.text),
        purchaseDate: _selectedPurchaseDate,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        expenseCategory: _selectedExpenseCategory,
        unit: assumedUnit, // ASSUMED VALUE
        quantity: _quantityController.text.isNotEmpty ? double.tryParse(_quantityController.text) : null,
        baseQuantity: _baseQuantityController.text.isNotEmpty ? double.tryParse(_baseQuantityController.text) : null,
        odometerReading: _odometerReadingController.text.isNotEmpty ? double.tryParse(_odometerReadingController.text) : null,
        isCompanyExpense: _isCompanyExpense,
        vehicleDesignation: _selectedVehicleDesignation,
        // FIX: Use the directly selected vendor/subtrade (no more complex lookup needed!)
        vendorOrSubtrade: _selectedVendorOrSubtrade,
      );

      widget.onAddExpense(newExpense, widget.isEditing);
      resetForm();
    }
  }
  // end method: _submitForm

  @override
  Widget build(BuildContext context) {
    final buttonText = widget.isEditing ? 'Update Expense' : 'Add Expense';

    // Disable the Project dropdown if Company Expense is checked
    final bool isProjectDropdownEnabled = !_isCompanyExpense;

    // Set Project Dropdown Hint/Value based on state
    Project? currentProjectSelection = _isCompanyExpense ? _getInternalProject() : _selectedProject;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Row 1: Project Dropdown, Expense Category, and Control Checkboxes
          Row(
            crossAxisAlignment: CrossAxisAlignment.end, // Align widgets to the bottom
            children: [
              // Project Dropdown (Narrowed)
              Flexible(
                flex: 4,
                child: DropdownButtonFormField<Project>(
                  decoration: InputDecoration(
                    labelText: 'Select Project',
                    suffixIcon: isProjectDropdownEnabled ? const Text('*') : null,
                  ),
                  isDense: true,
                  value: currentProjectSelection,
                  onChanged: isProjectDropdownEnabled
                      ? (Project? newValue) {
                    setState(() {
                      _selectedProject = newValue;
                    });
                  }
                      : null,
                  items: widget.availableProjects.map((project) {
                    final isInternal = project.projectName == 'Internal Company Project';
                    // Only display the name, without the internal ID
                    final displayName = isInternal ? 'Internal Company Project' : project.projectName;
                    return DropdownMenuItem<Project>(
                      value: project,
                      child: Text(displayName),
                    );
                  }).toList(),
                  validator: (value) {
                    if (isProjectDropdownEnabled && value == null) {
                      return 'Project is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Expense Category Dropdown (Standard width)
              Flexible(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Expense Category *'),
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
                      _isFuelCategory = newValue == 'Fuel';
                      if (!_isFuelCategory) {
                        _odometerReadingController.clear();
                        _quantityController.clear();
                      }
                    });
                  },
                  validator: (value) => value == null ? 'Category is required' : null,
                ),
              ),
              const SizedBox(width: 16),

              // Control Checkboxes (Company Expense and Show Completed)
              // Grouped horizontally for minimal vertical space
              Flexible(
                flex: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Company Expense Checkbox Group
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _isCompanyExpense,
                            onChanged: (bool? newValue) {
                              setState(() {
                                _isCompanyExpense = newValue ?? false;
                                if (newValue == true) {
                                  _selectedProject = null;
                                }
                                if (newValue == false && _selectedProject == null) {
                                  _selectedProject = _getInternalProject();
                                }
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Text('Company Expense', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Project Filter Checkbox Group
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _showCompletedProjects,
                            onChanged: (bool? newValue) {
                              setState(() {
                                _showCompletedProjects = newValue ?? false;
                                widget.onProjectFilterToggle(_showCompletedProjects);
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Text('Show Completed', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Row 2: Vendor/Subtrade and Item Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Vendor/Subtrade (Optional)'),
                  // FIX: Use the new dedicated state variable
                  value: _selectedVendorOrSubtrade,
                  items: widget.vendors.map((vendor) {
                    return DropdownMenuItem<String>(
                      value: vendor,
                      child: Text(vendor),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      // FIX: Update the new dedicated state variable
                      _selectedVendorOrSubtrade = newValue;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _itemNameController,
                  inputFormatters: [CapitalizeEachWordInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Item Name (Optional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Receipt Total and Purchase Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt Total *',
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter a total cost';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Date picker trigger field
              Expanded(
                child: TextFormField(
                  // Use the date display text as the field value, but disable editing
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat('MMM d, yyyy').format(_selectedPurchaseDate),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Select Purchase Date',
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: () => _selectPurchaseDate(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),


          // Conditional Fuel Fields (Quantity, Odometer)
          if (_isFuelCategory) ...[
            // Row 4a: Quantity and Odometer (Unit removed)
            Row(
              children: [
                Expanded(
                  // Quantity field now takes half the row (it shared space with Odometer)
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      // Label updated to reflect the unit setting (placeholder)
                      labelText: 'Fuel Quantity (Liters)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _odometerReadingController,
                    // Label updated to reflect the unit setting (placeholder)
                    decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Row 5: Description (Full Width, single line)
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description/Notes (Optional)'),
            // Set maxLines to 1 for single line input
            maxLines: 1,
          ),
          const SizedBox(height: 24),

          // Row 6: Submit Button (Full Width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitForm,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

// start class: CostRecordForm
class CostRecordForm extends StatefulWidget {
  final List<Project> availableProjects;
  final List<String> expenseCategories;
  final List<String> vendors;
  final List<String> vehicleDesignations;
  final Function(JobMaterials expense, bool isEditing) onAddExpense;
  final Function(bool showCompleted) onProjectFilterToggle;
  final bool isEditing;

  // start method: constructor
  const CostRecordForm({
    super.key,
    required this.availableProjects,
    required this.expenseCategories,
    required this.vendors,
    required this.vehicleDesignations,
    required this.onAddExpense,
    required this.onProjectFilterToggle,
    required this.isEditing,
  });
  // end method: constructor

  @override
  // Expose the State class type
  State<CostRecordForm> createState() => CostRecordFormState();
}
// end class: CostRecordForm