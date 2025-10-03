// lib/expenses_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/input_formatters.dart';
//import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/widgets/app_setting_list_card.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final SettingsService _settingsService = SettingsService.instance;

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<String> _vehicles = [];
  List<String> _vendors = [];

  final dbNotifier = DatabaseHelperV2.instance.databaseNotifier;


  @override
  void initState() {
    super.initState();
    _loadData();
    dbNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _vehicleController.dispose();
    _vendorController.dispose();
    dbNotifier.removeListener(_loadData);
    super.dispose();
  }


  // REVISED FIX: Trusting the analyzer that rawSettings is not null.
  Future<void> _loadData() async {
    final rawSettings = await _settingsService.loadSettings();

    // THIS IS THE REVISED FIX
    final settings = rawSettings;

    final cats = await DatabaseHelperV2.instance.getExpenseCategoriesV2();

    if (!mounted) return;

    setState(() {
      _categories = cats;
      _vehicles = List<String>.from(settings.vehicleDesignations);
      _vendors = List<String>.from(settings.vendors);
    });
  }

  Future<void> _addCategory() async {
    FocusScope.of(context).unfocus();
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;

    await DatabaseHelperV2.instance.addExpenseCategoryV2(ExpenseCategory(name: name));
    _categoryController.clear();
  }

  Future<void> _deleteCategory(int id) async {
    await DatabaseHelperV2.instance.deleteRecordV2(id: id, fromTable: 'expense_categories');
  }

  Future<void> _updateCategory(ExpenseCategory category) async {
    await DatabaseHelperV2.instance.updateExpenseCategoryV2(category);
  }

  Future<void> _addOption(TextEditingController controller, List<String> list) async {
    FocusScope.of(context).unfocus();
    final name = controller.text.trim();
    if (name.isEmpty) return;

    list.add(name);
    controller.clear();

    await _saveSettings();
    _loadData();
  }

  Future<void> _updateOption(List<String> list, int index, String newValue) async {
    list[index] = newValue;
    await _saveSettings();
    _loadData();
  }

  Future<void> _removeOption(List<String> list, int index) async {
    list.removeAt(index);
    await _saveSettings();
    _loadData();
  }

  // REVISED FIX: Trusting the analyzer that rawSettings is not null.
  Future<void> _saveSettings() async {
    final rawSettings = await _settingsService.loadSettings();

    // THIS IS THE REVISED FIX
    final currentSettings = rawSettings;

    final updatedSettings = currentSettings.copyWith(
      vehicleDesignations: _vehicles,
      vendors: _vendors,
    );
    await _settingsService.saveSettings(updatedSettings);
  }

  // Unchanged UI methods below...
  Widget _buildForm(String label, TextEditingController controller, VoidCallback onAdd) {
    final bool applyCapitalization = label != 'Vehicle Designation';
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

  @override
  Widget build(BuildContext context) {
    void openEditDialog(String title, String currentValue, Function(String) onSave, VoidCallback onDelete) {
      _showEditDialog(context, title, currentValue, onSave, onDelete);
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildForm('Expense Category', _categoryController, _addCategory),
                  const SizedBox(width: 16),
                  _buildForm('Vehicle Designation', _vehicleController, () async => _addOption(_vehicleController, _vehicles)),
                  const SizedBox(width: 16),
                  _buildForm('Vendor / Subtrade', _vendorController, () async => _addOption(_vendorController, _vendors)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      children: [
                        Expanded(
                          child: AppSettingListCard(
                            title: 'Expense Categories',
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
                  Flexible(
                    child: Column(
                      children: [
                        Expanded(
                          child: AppSettingListCard(
                            title: 'Vehicle Designations',
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
                  Flexible(
                    child: Column(
                      children: [
                        Expanded(
                          child: AppSettingListCard(
                            title: 'Vendors / Subtrades',
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
}
