// lib/cost_record_form.dart (COMPLETE FILE - Fixed with Integer Project IDs)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';

class CostRecordForm extends StatefulWidget {
  final ValueNotifier<List<Project>> availableProjectsNotifier;
  final ValueNotifier<List<String>> expenseCategoriesNotifier;
  final ValueNotifier<List<String>> vendorsNotifier;
  final ValueNotifier<List<String>> vehicleDesignationsNotifier;
  final Function(JobMaterials expense, bool isEditing) onAddExpense;
  final Function(bool showCompleted) onProjectFilterToggle;
  final VoidCallback onClearForm;
  final bool isEditing;
  final ValueNotifier<bool> onCompanyExpenseToggle;
  final bool isCollapsed;
  final VoidCallback onCollapseToggle;

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
    required this.onCompanyExpenseToggle,
    required this.isCollapsed,
    required this.onCollapseToggle,
  });

  @override
  State<CostRecordForm> createState() => CostRecordFormState();
}

class CostRecordFormState extends State<CostRecordForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _itemNameController = TextEditingController();
  final FocusNode _itemNameFocusNode = FocusNode();

  final TextEditingController _costController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _odometerReadingController = TextEditingController();

  // CHANGE: Use int ID instead of Project object
  int? selectedProjectId;
  DateTime _selectedPurchaseDate = DateTime.now();
  String? selectedExpenseCategory;
  String? _selectedVendorOrSubtrade;
  String? _selectedVehicleDesignation;
  bool isFuelCategory = false;

  static const int _internalProjectId = 0;
  int? _editingExpenseId;

  String getCurrentItemName() {
    return _itemNameController.text;
  }

  void setItemName(String newName) {
    if (mounted && _itemNameController.text != newName) {
      setState(() {
        _itemNameController.text = newName;
      });
    }
  }

  void triggerSubmit() {
    _submitForm();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemNameFocusNode.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _odometerReadingController.dispose();
    super.dispose();
  }

  Project? getInternalProject() {
    try {
      return widget.availableProjectsNotifier.value.firstWhere((p) => p.id == _internalProjectId);
    } catch (_) {
      return null;
    }
  }

  void populateForm(JobMaterials expense) {
    setState(() {
      _editingExpenseId = expense.id;
      _itemNameController.text = expense.itemName ?? '';
      _costController.text = expense.cost.toStringAsFixed(2);
      _quantityController.text = expense.quantity?.toStringAsFixed(2) ?? '';
      _odometerReadingController.text = expense.odometerReading?.toStringAsFixed(0) ?? '';
      _selectedPurchaseDate = expense.purchaseDate;
      isFuelCategory = expense.expenseCategory == 'Fuel';

      widget.onCompanyExpenseToggle.value = expense.isCompanyExpense;

      if (widget.expenseCategoriesNotifier.value.contains(expense.expenseCategory)) {
        selectedExpenseCategory = expense.expenseCategory;
      } else {
        selectedExpenseCategory = null;
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

      selectedProjectId = expense.projectId;
    });
  }

  void resetForm() {
    _formKey.currentState?.reset();
    _itemNameController.clear();
    _costController.clear();
    _quantityController.clear();
    _odometerReadingController.clear();
    setState(() {
      _editingExpenseId = null;
      _selectedPurchaseDate = DateTime.now();
      isFuelCategory = false;
      selectedExpenseCategory = null;
      _selectedVendorOrSubtrade = null;
      selectedProjectId = widget.availableProjectsNotifier.value
          .firstWhere((p) => !p.isInternal, orElse: () => widget.availableProjectsNotifier.value.first)
          .id;
    });

    widget.onCompanyExpenseToggle.value = false;
  }

  void setSelectedProjectId(int? projectId) {
    setState(() {
      selectedProjectId = projectId;
    });
  }

  void focusFirstField() {
    _itemNameFocusNode.requestFocus();
  }

  void _submitForm() {
    print('Debug: Submit called, selectedProjectId = $selectedProjectId');
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!widget.onCompanyExpenseToggle.value && selectedProjectId == null) {
      return;
    }

    final bool isCompanyExpenseFromParent = widget.onCompanyExpenseToggle.value;
    final int submissionProjectId = isCompanyExpenseFromParent ? _internalProjectId : selectedProjectId!;

    final String submittedItemName = _itemNameController.text.isNotEmpty
        ? _itemNameController.text
        : 'General Expense';

    final newExpense = JobMaterials(
        id: _editingExpenseId,
        projectId: submissionProjectId,
        itemName: submittedItemName,
        cost: double.parse(_costController.text),
        purchaseDate: _selectedPurchaseDate,
        description: null,
        expenseCategory: selectedExpenseCategory,
        isCompanyExpense: isCompanyExpenseFromParent,
        vehicleDesignation: isCompanyExpenseFromParent ? _selectedVehicleDesignation : null,
        vendorOrSubtrade: _selectedVendorOrSubtrade,
        unit: isFuelCategory ? 'Liters' : null,
        quantity: isCompanyExpenseFromParent ? (_quantityController.text.isNotEmpty ? double.tryParse(_quantityController.text) : null) : null,
        odometerReading: isCompanyExpenseFromParent ? (_odometerReadingController.text.isNotEmpty ? double.tryParse(_odometerReadingController.text) : null) : null,
        baseQuantity: null
    );
    widget.onAddExpense(newExpense, widget.isEditing);
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

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: widget.vendorsNotifier,
                    builder: (context, vendors, _) {
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Vendor'),
                        value: _selectedVendorOrSubtrade,
                        onChanged: (String? newValue) => setState(() => _selectedVendorOrSubtrade = newValue),
                        items: vendors.map((vendor) => DropdownMenuItem<String>(
                          value: vendor,
                          child: Text(vendor),
                        )).toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _selectPurchaseDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(DateFormat('MMM dd').format(_selectedPurchaseDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(labelText: 'Cost *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (double.tryParse(value) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ValueListenableBuilder<bool>(
              valueListenable: widget.onCompanyExpenseToggle,
              builder: (context, isCompanyExpenseFromParent, _) {
                if (!isCompanyExpenseFromParent) return const SizedBox.shrink();

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<List<String>>(
                            valueListenable: widget.vehicleDesignationsNotifier,
                            builder: (context, vehicles, _) {
                              return DropdownButtonFormField<String>(
                                decoration: const InputDecoration(labelText: 'Vehicle Designation'),
                                value: _selectedVehicleDesignation,
                                onChanged: (String? newValue) => setState(() => _selectedVehicleDesignation = newValue),
                                items: vehicles.map((vehicle) => DropdownMenuItem<String>(
                                  value: vehicle,
                                  child: Text(vehicle),
                                )).toList(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: isFuelCategory ? 'Quantity (Liters)' : 'Quantity',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _odometerReadingController,
                            decoration: const InputDecoration(labelText: 'Odometer Reading'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            SizedBox(
              height: 0,
              width: 0,
              child: Focus(
                focusNode: _itemNameFocusNode,
                child: const SizedBox.shrink(),
              ),
            ),

            Row(
              children: [
                Flexible(
                  flex: 1,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600]),
                      onPressed: () {
                        resetForm();
                        widget.onClearForm();
                      },
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
      ),
    );
  }
}