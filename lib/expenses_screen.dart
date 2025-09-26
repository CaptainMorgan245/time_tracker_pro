// lib/expenses_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/input_formatters.dart';
import 'package:time_tracker_pro/settings_model.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseCategoryRepository _repo = ExpenseCategoryRepository();
  final SettingsService _settingsService = SettingsService.instance;

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<String> _vehicles = [];
  List<String> _vendors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // start method: _loadData
  Future<void> _loadData() async {
    final rawSettings = await _settingsService.loadSettings();

    // FIX 1: Use explicit casting (as Map<String, dynamic>) within the conditional
    // to satisfy the compiler that the parameter is the correct type.
    final settings = (rawSettings is Map<String, dynamic>)
        ? SettingsModel.fromMap(rawSettings as Map<String, dynamic>)
        : (rawSettings is SettingsModel ? rawSettings : SettingsModel());

    final cats = await _repo.getExpenseCategories();

    setState(() {
      _categories = cats;
      _vehicles = List<String>.from(settings.vehicleDesignations);
      _vendors = List<String>.from(settings.vendors);
    });
  }
  // end method: _loadData

  // start method: _addCategory
  Future<void> _addCategory() async {
    FocusScope.of(context).unfocus();
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;
    await _repo.insertExpenseCategory(ExpenseCategory(name: name));
    _categoryController.clear();
    _loadData();
  }
  // end method: _addCategory

  // start method: _deleteCategory
  Future<void> _deleteCategory(int id) async {
    await _repo.deleteExpenseCategory(id);
    _loadData();
  }
  // end method: _deleteCategory

  // start method: _updateCategory
  Future<void> _updateCategory(ExpenseCategory category) async {
    await _repo.updateExpenseCategory(category);
    _loadData();
  }
  // end method: _updateCategory

  // start method: _addOption
  Future<void> _addOption(TextEditingController controller, List<String> list) async {
    FocusScope.of(context).unfocus();
    final name = controller.text.trim();
    if (name.isEmpty) return;

    list.add(name);
    controller.clear();

    await _saveSettings();
    _loadData();
  }
  // end method: _addOption

  // start method: _updateOption
  Future<void> _updateOption(List<String> list, int index, String newValue) async {
    list[index] = newValue;
    await _saveSettings();
    _loadData();
  }
  // end method: _updateOption

  // start method: _removeOption
  Future<void> _removeOption(List<String> list, int index) async {
    list.removeAt(index);
    await _saveSettings();
    _loadData();
  }
  // end method: _removeOption

  // start method: _saveSettings
  Future<void> _saveSettings() async {
    final rawSettings = await _settingsService.loadSettings();

    // FIX 2: Apply explicit casting for the conversion in _saveSettings as well.
    final currentSettings = (rawSettings is Map<String, dynamic>)
        ? SettingsModel.fromMap(rawSettings as Map<String, dynamic>)
        : (rawSettings is SettingsModel ? rawSettings : SettingsModel());

    final updatedSettings = currentSettings.copyWith(
      vehicleDesignations: _vehicles,
      vendors: _vendors,
    );

    await _settingsService.saveSettings(updatedSettings);
  }
  // end method: _saveSettings

  // start method: _buildForm
  Widget _buildForm(String label, TextEditingController controller, VoidCallback onAdd) {
    // FIX 1: Correctly set the flag to exclude Vehicle Designation
    final bool applyCapitalization = label != 'Vehicle Designation';

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: controller,
                // FIX 2: Use the conditional logic to either apply the formatter or an empty list.
                inputFormatters: applyCapitalization
                    ? [CapitalizeEachWordInputFormatter()]
                    : [],
                decoration: InputDecoration(labelText: label),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: onAdd, child: const Text('Add')),
            ],
          ),
        ),
      ),
    );
  }
// end method: _buildForm

  // start method: _buildList
  Widget _buildList(String title, List<String> items, Function(int) onRemove, Function(int) onEdit) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final value = items[index];
                    return ListTile(
                      title: Text(value),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => onEdit(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => onRemove(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // end method: _buildList

  void _showEditDialog(
      BuildContext context,
      String title,
      String currentValue,
      Function(String) onSave,
      ) {
    final TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: title),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onSave(controller.text.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top row: pinned input forms
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildForm('Expense Category', _categoryController, _addCategory),
                  const SizedBox(width: 16),
                  _buildForm('Vehicle Designation', _vehicleController, () async => _addOption(_vehicleController, _vehicles)),
                  const SizedBox(width: 16),
                  _buildForm('Vendor / Subtrade', _vendorController, () async => _addOption(_vendorController, _vendors)),
                ],
              ),
            ),
            const Divider(height: 1),
            // Bottom row: scrollable lists side-by-side
            SizedBox(
              height: 400,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildList(
                      'Expense Categories',
                      _categories.map((cat) => cat.name).toList(),
                          (index) => _deleteCategory(_categories[index].id!),
                          (index) {
                        final category = _categories[index];
                        _showEditDialog(
                          context,
                          'Expense Category',
                          category.name,
                              (newValue) {
                            final updatedCategory = category.copyWith(name: newValue);
                            _updateCategory(updatedCategory);
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildList(
                      'Vehicle Designations',
                      _vehicles,
                          (index) => _removeOption(_vehicles, index),
                          (index) {
                        final currentValue = _vehicles[index];
                        _showEditDialog(
                          context,
                          'Vehicle Designation',
                          currentValue,
                              (newValue) => _updateOption(_vehicles, index, newValue),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildList(
                      'Vendors / Subtrades',
                      _vendors,
                          (index) => _removeOption(_vendors, index),
                          (index) {
                        final currentValue = _vendors[index];
                        _showEditDialog(
                          context,
                          'Vendor / Subtrade',
                          currentValue,
                              (newValue) => _updateOption(_vendors, index, newValue),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}