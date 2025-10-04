// lib/cost_record_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/input_formatters.dart';

class CostRecordForm extends StatefulWidget {
  final ValueNotifier<List<Project>> availableProjectsNotifier;
  final ValueNotifier<List<String>> expenseCategoriesNotifier;
  final ValueNotifier<List<String>> vendorsNotifier;
  final ValueNotifier<List<String>> vehicleDesignationsNotifier;
  final Function(JobMaterials expense, bool isEditing) onAddExpense;
  final Function(bool showCompleted) onProjectFilterToggle;
  final VoidCallback onClearForm;
  final bool isEditing;

  const CostRecordForm({
    super.key,
    required this.availableProjectsNotifier,
    required this.expenseCategoriesNotifier,
    required this.vendorsNotifier,
    required this.vehicleDesignationsNotifier,
    required this.onAddExpense,
    required this.onProjectFilterToggle,
    required this.onClearForm,
    required this.isEditing,
  });

  @override
  State<CostRecordForm> createState() => CostRecordFormState();
}

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
  String? _selectedVendorOrSubtrade;
  String? _selectedVehicleDesignation;

  static const int _internalProjectId = 0;
  bool _isCompanyExpense = false;
  bool _isFuelCategory = false;
  bool showCompletedProjects = false;
  int? _editingExpenseId;

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

  Project? _getInternalProject() {
    return widget.availableProjectsNotifier.value.cast<Project?>().firstWhere(
          (p) => p?.id == _internalProjectId,
      orElse: () => null,
    );
  }

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

      if (widget.expenseCategoriesNotifier.value.contains(expense.expenseCategory)) {
        _selectedExpenseCategory = expense.expenseCategory;
      } else {
        _selectedExpenseCategory = null;
      }
      if (widget.vehicleDesignationsNotifier.value.contains(expense.vehicleDesignation)) {
        _selectedVehicleDesignation = expense.vehicleDesignation;
      } else {
        _selectedVehicleDesignation = null;
      }
      if (widget.vendorsNotifier.value.contains(expense.vendorOrSubtrade)) {
        _selectedVendorOrSubtrade = expense.vendorOrSubtrade;
      } else {
        _selectedVendorOrSubtrade = null;
      }

      _isFuelCategory = expense.expenseCategory == 'Fuel';
      _selectedProject = widget.availableProjectsNotifier.value.cast<Project?>().firstWhere(
            (p) => p?.id == expense.projectId,
        orElse: () => null,
      );
    });
  }

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
      _selectedVendorOrSubtrade = null;
      _selectedProject = null;
    });
  }

  void _submitForm() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_formKey.currentState!.validate()) {
      final int submissionProjectId = _isCompanyExpense ? _internalProjectId : _selectedProject!.id!;
      final newExpense = JobMaterials(
          id: _editingExpenseId,
          projectId: submissionProjectId,
          itemName: _itemNameController.text.isEmpty ? 'N/A' : _itemNameController.text,
          cost: double.parse(_costController.text),
          purchaseDate: _selectedPurchaseDate,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          expenseCategory: _selectedExpenseCategory,
          isCompanyExpense: _isCompanyExpense,
          vehicleDesignation: _isCompanyExpense ? _selectedVehicleDesignation : null,
          vendorOrSubtrade: _selectedVendorOrSubtrade,
          unit: 'Liters',
          quantity: _isFuelCategory ? (_quantityController.text.isNotEmpty ? double.tryParse(_quantityController.text) : null) : null,
          baseQuantity: _baseQuantityController.text.isNotEmpty ? double.tryParse(_baseQuantityController.text) : null,
          odometerReading: _isCompanyExpense ? (_odometerReadingController.text.isNotEmpty ? double.tryParse(_odometerReadingController.text) : null) : null
      );
      widget.onAddExpense(newExpense, widget.isEditing);
    }
  }

  Future<void> _selectPurchaseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedPurchaseDate, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (picked != null && picked != _selectedPurchaseDate) {
      setState(() => _selectedPurchaseDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = widget.isEditing ? 'Update Expense' : 'Add Expense';
    final bool isProjectDropdownEnabled = !_isCompanyExpense;
    Project? currentProjectSelection = _isCompanyExpense ? _getInternalProject() : _selectedProject;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                flex: 4,
                child: ValueListenableBuilder<List<Project>>(
                    valueListenable: widget.availableProjectsNotifier,
                    builder: (context, projects, _) {
                      return DropdownButtonFormField<Project>(
                        decoration: InputDecoration(labelText: 'Select Project', suffixIcon: isProjectDropdownEnabled ? const Text('*') : null,),
                        isDense: true,
                        value: currentProjectSelection,
                        onChanged: isProjectDropdownEnabled ? (Project? newValue) => setState(() => _selectedProject = newValue) : null,
                        items: projects.map((project) {
                          final displayName = project.isInternal ? 'Internal Company Project' : project.projectName;
                          return DropdownMenuItem<Project>(value: project, child: Text(displayName));
                        }).toList(),
                        validator: (value) => (isProjectDropdownEnabled && value == null) ? 'Project is required' : null,
                      );
                    }
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 5,
                child: ValueListenableBuilder<List<String>>(
                    valueListenable: widget.expenseCategoriesNotifier,
                    builder: (context, categories, _) {
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Expense Category *'),
                        value: _selectedExpenseCategory,
                        items: categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedExpenseCategory = newValue;
                            _isFuelCategory = newValue == 'Fuel';
                          });
                        },
                        validator: (v) => v == null ? 'Category is required' : null,
                      );
                    }
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded( child: Column( mainAxisSize: MainAxisSize.min, children: [
                      Checkbox( value: _isCompanyExpense, onChanged: (bool? newValue) {
                        setState(() {
                          _isCompanyExpense = newValue ?? false;
                          if (_isCompanyExpense) {
                            _selectedProject = null;
                          }
                        });
                      }, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, ),
                      const Text('Company Expense', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    ],),),
                    const SizedBox(width: 8),
                    Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Checkbox(value: showCompletedProjects, onChanged: (bool? newValue) { setState(() { showCompletedProjects = newValue ?? false; widget.onProjectFilterToggle(showCompletedProjects); }); }, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,),
                      const Text('Show Completed', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    ],),),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                    valueListenable: widget.vendorsNotifier,
                    builder: (context, vendors, _) {
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Vendor/Subtrade (Optional)'),
                        value: _selectedVendorOrSubtrade,
                        items: vendors.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                        onChanged: (String? newValue) => setState(() => _selectedVendorOrSubtrade = newValue),
                      );
                    }
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(controller: _itemNameController, inputFormatters: [CapitalizeEachWordInputFormatter()], decoration: const InputDecoration(labelText: 'Item Name (Optional)')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextFormField(controller: _costController, decoration: const InputDecoration(labelText: 'Receipt Total *', prefixText: '\$'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) { if (v == null || v.isEmpty) return 'Cost is required'; if (double.tryParse(v) == null) return 'Invalid number'; return null; },),),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(readOnly: true, controller: TextEditingController(text: DateFormat('MMM d, yyyy').format(_selectedPurchaseDate)), decoration: InputDecoration(labelText: 'Select Purchase Date', suffixIcon: const Icon(Icons.calendar_today)), onTap: () => _selectPurchaseDate(context),),),
          ],),
          const SizedBox(height: 16),

          // --- LOGIC CHANGE IS HERE ---
          // This section handles showing the conditional fields.
          // The structure is now cleaner.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // This entire block only shows for Company Expense.
              if (_isCompanyExpense)
                Expanded(
                  // Use a Row to hold Vehicle, Odometer, and Liters
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Dropdown
                      Expanded(
                        flex: 3,
                        child: ValueListenableBuilder<List<String>>(
                            valueListenable: widget.vehicleDesignationsNotifier,
                            builder: (context, designations, _) {
                              return DropdownButtonFormField<String>(
                                isDense: true,
                                decoration: const InputDecoration(labelText: 'Vehicle *'),
                                value: _selectedVehicleDesignation,
                                items: designations.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                onChanged: (String? newValue) => setState(() => _selectedVehicleDesignation = newValue),
                                validator: (v) => _isCompanyExpense && v == null ? 'Vehicle is required' : null,
                              );
                            }),
                      ),
                      const SizedBox(width: 8),
                      // Odometer Field
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _odometerReadingController,
                          decoration: const InputDecoration(labelText: 'Odometer'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      // Liters field ONLY appears if it's also Fuel category
                      if (_isFuelCategory) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(labelText: 'Liters'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // This handles the case where it's Fuel but NOT a Company Expense.
              // For example, fuel for a personal vehicle on a specific job.
              if (!_isCompanyExpense && _isFuelCategory)
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Liters'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
            ],
          ),
          // Add spacing only if any of the above fields were visible.
          if (_isCompanyExpense || _isFuelCategory) const SizedBox(height: 16),
          // --- END OF LOGIC CHANGE ---

          TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description/Notes (Optional)'), maxLines: 1),
          const SizedBox(height: 24),
          Row(
            children: [
              Flexible(
                flex: 1,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onClearForm,
                    child: Text(widget.isEditing ? 'Cancel' : 'Clear'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 3,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    child: Text(buttonText),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

