// lib/cost_record_form.dart
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
  final Function(bool isCompanyExpense) onCompanyExpenseToggle;
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
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _odometerReadingController = TextEditingController();

  Project? selectedProject;
  DateTime _selectedPurchaseDate = DateTime.now();
  String? selectedExpenseCategory;
  String? _selectedVendorOrSubtrade;
  String? _selectedVehicleDesignation;
  bool isFuelCategory = false;

  static const int _internalProjectId = 0;
  bool isCompanyExpense = false;
  bool showCompletedProjects = false;
  int? _editingExpenseId;

  @override
  void dispose() {
    _itemNameController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
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
      _itemNameController.text = expense.itemName;
      _costController.text = expense.cost.toStringAsFixed(2);
      _descriptionController.text = expense.description ?? '';
      _quantityController.text = expense.quantity?.toStringAsFixed(2) ?? '';
      _odometerReadingController.text = expense.odometerReading?.toStringAsFixed(0) ?? '';
      _selectedPurchaseDate = expense.purchaseDate;
      isCompanyExpense = expense.isCompanyExpense;
      isFuelCategory = expense.expenseCategory == 'Fuel';

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

      selectedProject = widget.availableProjectsNotifier.value.cast<Project?>().firstWhere(
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
    setState(() {
      _editingExpenseId = null;
      _selectedPurchaseDate = DateTime.now();
      isCompanyExpense = false;
      isFuelCategory = false;
      selectedExpenseCategory = null;
      _selectedVehicleDesignation = null;
      _selectedVendorOrSubtrade = null;
      selectedProject = null;
    });
  }

  void setSelectedProject(Project project) {
    setState(() {
      selectedProject = project;
    });
  }

  void _submitForm() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_formKey.currentState!.validate()) {
      final int submissionProjectId = isCompanyExpense ? _internalProjectId : selectedProject!.id!;
      final newExpense = JobMaterials(
          id: _editingExpenseId,
          projectId: submissionProjectId,
          itemName: _itemNameController.text.isEmpty ? 'N/A' : _itemNameController.text,
          cost: double.parse(_costController.text),
          purchaseDate: _selectedPurchaseDate,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          expenseCategory: selectedExpenseCategory,
          isCompanyExpense: isCompanyExpense,
          vehicleDesignation: isCompanyExpense ? _selectedVehicleDesignation : null,
          vendorOrSubtrade: _selectedVendorOrSubtrade,
          unit: isFuelCategory ? 'Liters' : null,
          quantity: isCompanyExpense ? (_quantityController.text.isNotEmpty ? double.tryParse(_quantityController.text) : null) : null,
          odometerReading: isCompanyExpense ? (_odometerReadingController.text.isNotEmpty ? double.tryParse(_odometerReadingController.text) : null) : null,
          baseQuantity: null
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
    final bool isProjectDropdownEnabled = !isCompanyExpense;
    Project? currentProjectSelection = isCompanyExpense ? getInternalProject() : selectedProject;

    // This is the full body of the form, extracted into a variable for the animation.
    final formBody = Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      // FIXED: Replaced deprecated 'value' with 'initialValue'.
                      initialValue: _selectedVendorOrSubtrade,
                      items: vendors.map((v) => DropdownMenuItem<String>(
                          value: v,
                          child: Text(v)
                      )).toList(),
                      onChanged: (String? newValue) => setState(() => _selectedVendorOrSubtrade = newValue),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _itemNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Item Name (Optional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                      labelText: 'Receipt Total *',
                      prefixText: '\$'
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Cost is required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: DateFormat('MMM d, yyyy').format(_selectedPurchaseDate)
                  ),
                  decoration: const InputDecoration(
                      labelText: 'Select Purchase Date',
                      suffixIcon: Icon(Icons.calendar_today)
                  ),
                  onTap: () => _selectPurchaseDate(context),
                ),
              ),
            ],
          ),
          if (isCompanyExpense) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: widget.vehicleDesignationsNotifier,
                    builder: (context, designations, _) {
                      return DropdownButtonFormField<String>(
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'Vehicle *'),
                        // FIXED: Replaced deprecated 'value' with 'initialValue'.
                        initialValue: _selectedVehicleDesignation,
                        items: designations.map((v) => DropdownMenuItem<String>(
                            value: v,
                            child: Text(v)
                        )).toList(),
                        onChanged: (String? newValue) => setState(() => _selectedVehicleDesignation = newValue),
                        validator: (v) => isCompanyExpense && v == null ? 'Vehicle is required' : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _odometerReadingController,
                    decoration: const InputDecoration(labelText: 'Odometer'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Liters: Qty(if fuel)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description/Notes (Optional)'),
            maxLines: 1,
          ),
          const SizedBox(height: 24),
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
    );

    // THIS IS THE SINGLE, CORRECT RETURN STATEMENT FOR THE BUILD METHOD
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  flex: 4,
                  child: ValueListenableBuilder<List<Project>>(
                    valueListenable: widget.availableProjectsNotifier,
                    builder: (context, projects, _) {
                      return DropdownButtonFormField<Project>(
                        decoration: InputDecoration(
                          labelText: 'Select Project',
                          suffixIcon: isProjectDropdownEnabled ? const Text('*') : null,
                        ),
                        isDense: true,
                        // FIXED: Replaced deprecated 'value' with 'initialValue'.
                        initialValue: currentProjectSelection,
                        onChanged: isProjectDropdownEnabled
                            ? (Project? newValue) => setState(() => selectedProject = newValue)
                            : null,
                        items: projects.map((project) {
                          final displayName = project.isInternal
                              ? 'Internal Company Project'
                              : project.projectName;
                          return DropdownMenuItem<Project>(
                            value: project,
                            child: Text(displayName, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        validator: (value) => (isProjectDropdownEnabled && value == null)
                            ? 'Project is required'
                            : null,
                      );
                    },
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
                        // FIXED: Replaced deprecated 'value' with 'initialValue'.
                        initialValue: selectedExpenseCategory,
                        items: categories.map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c)
                        )).toList(),
                        onChanged: (String? newValue) => setState(() {
                          selectedExpenseCategory = newValue;
                          isFuelCategory = newValue == 'Fuel';
                        }),
                        validator: (v) => v == null ? 'Category is required' : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isCompanyExpense,
                              onChanged: (bool? newValue) {
                                setState(() {
                                  isCompanyExpense = newValue ?? false;
                                  if (isCompanyExpense) selectedProject = null;
                                  widget.onCompanyExpenseToggle(isCompanyExpense);
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text(
                              'Company Expense',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: showCompletedProjects,
                              onChanged: (bool? newValue) {
                                setState(() {
                                  showCompletedProjects = newValue ?? false;
                                  widget.onProjectFilterToggle(showCompletedProjects);
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text(
                              'Show Completed',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // This is the expand/collapse button
                IconButton(
                  icon: Icon(widget.isCollapsed ? Icons.expand_more : Icons.expand_less),
                  onPressed: widget.onCollapseToggle,
                ),
              ],
            ),
          ),
          // This widget handles the expand/collapse animation cleanly.
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            firstChild: const SizedBox.shrink(), // What to show when collapsed
            secondChild: formBody, // What to show when expanded
            crossFadeState: widget.isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
          ),
        ],
      ),
    );
  }
}
