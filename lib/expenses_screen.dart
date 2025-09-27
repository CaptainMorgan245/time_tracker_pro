// lib/expenses_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/input_formatters.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/widgets/app_setting_list_card.dart'; // Import reusable list component

// start class: ExpensesScreen
class ExpensesScreen extends StatefulWidget {
  // start method: constructor
  const ExpensesScreen({super.key});
  // end method: constructor

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}
// end class: ExpensesScreen

// start class: _ExpensesScreenState
class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseCategoryRepository _repo = ExpenseCategoryRepository();
  final SettingsService _settingsService = SettingsService.instance;

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<String> _vehicles = [];
  List<String> _vendors = [];

  // start method: initState
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  // end method: initState

  // start method: dispose
  @override
  void dispose() {
    _categoryController.dispose();
    _vehicleController.dispose();
    _vendorController.dispose();
    super.dispose();
  }
  // end method: _dispose

  // start method: _loadData
  Future<void> _loadData() async {
    final rawSettings = await _settingsService.loadSettings();

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
    final bool applyCapitalization = label != 'Vehicle Designation';

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: controller,
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

  // start method: _showEditDialog
  void _showEditDialog(
      BuildContext context,
      String title,
      String currentValue,
      Function(String) onSave,
      VoidCallback onDelete,
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
            // FIX: Safe Deletion UX: Delete button inside the dialog
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                onDelete();
                Navigator.of(context).pop();
              },
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
  // end method: _showEditDialog

  // start method: build
  @override
  Widget build(BuildContext context) {
    // Helper function for the repeatable action logic
    void openEditDialog(String title, String currentValue, Function(String) onSave, VoidCallback onDelete) {
      _showEditDialog(context, title, currentValue, onSave, onDelete);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: Column( // Main vertical alignment for FIXED TOP / EXPANDED BOTTOM
        children: [
          // Top row: pinned input forms (FIXED SECTION)
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

          // Bottom row: scrollable lists side-by-side (EXPANDED SCROLLABLE SECTION)
          Expanded( // Uses Expanded to fill remaining space
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expense Categories List (Individual Scroll Container)
                  Flexible(
                    child: Column( // Must use Column to support Expanded child
                      children: [
                        Expanded( // Forces the list to use available space and scroll internally
                          child: AppSettingListCard(
                            title: 'Expense Categories', // Title added back for context
                            items: _categories.map((cat) => cat.name).toList(),
                            onEdit: (index) {
                              final category = _categories[index];
                              openEditDialog(
                                'Expense Category',
                                category.name,
                                    (newValue) {
                                  final updatedCategory = category.copyWith(name: newValue);
                                  _updateCategory(updatedCategory);
                                },
                                    () => _deleteCategory(category.id!),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Vehicle Designations List (Individual Scroll Container)
                  Flexible(
                    child: Column( // Must use Column to support Expanded child
                      children: [
                        Expanded( // Forces the list to use available space and scroll internally
                          child: AppSettingListCard(
                            title: 'Vehicle Designations', // Title added back for context
                            items: _vehicles,
                            onEdit: (index) {
                              final currentValue = _vehicles[index];
                              openEditDialog(
                                'Vehicle Designation',
                                currentValue,
                                    (newValue) => _updateOption(_vehicles, index, newValue),
                                    () => _removeOption(_vehicles, index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Vendors List (Individual Scroll Container)
                  Flexible(
                    child: Column( // Must use Column to support Expanded child
                      children: [
                        Expanded( // Forces the list to use available space and scroll internally
                          child: AppSettingListCard(
                            title: 'Vendors / Subtrades', // Title added back for context
                            items: _vendors,
                            onEdit: (index) {
                              final currentValue = _vendors[index];
                              openEditDialog(
                                'Vendor / Subtrade',
                                currentValue,
                                    (newValue) => _updateOption(_vendors, index, newValue),
                                    () => _removeOption(_vendors, index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
// end method: build
}
// end class: _ExpensesScreenState
