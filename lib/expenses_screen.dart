// lib/expenses_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/expense_category_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseCategoryRepository _repo = ExpenseCategoryRepository();
  final SettingsService _settingsService = SettingsService();

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

  Future<void> _loadData() async {
    final settings = await _settingsService.loadSettings();
    final cats = await _repo.getExpenseCategories();
    setState(() {
      _categories = cats;
      _vehicles = List<String>.from(settings.vehicleDesignations ?? []);
      _vendors = List<String>.from(settings.vendors ?? []);
    });
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;
    await _repo.insertExpenseCategory(ExpenseCategory(name: name));
    _categoryController.clear();
    _loadData();
  }

  Future<void> _deleteCategory(int id) async {
    await _repo.deleteExpenseCategory(id);
    _loadData();
  }

  Future<void> _addVehicle() async {
    final name = _vehicleController.text.trim();
    if (name.isEmpty) return;
    _vehicles.add(name);
    _vehicleController.clear();
    await _saveSettings();
  }

  Future<void> _removeVehicle(int index) async {
    _vehicles.removeAt(index);
    await _saveSettings();
  }

  Future<void> _addVendor() async {
    final name = _vendorController.text.trim();
    if (name.isEmpty) return;
    _vendors.add(name);
    _vendorController.clear();
    await _saveSettings();
  }

  Future<void> _removeVendor(int index) async {
    _vendors.removeAt(index);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    final settings = await _settingsService.loadSettings();
    settings.vehicleDesignations = _vehicles;
    settings.vendors = _vendors;
    await _settingsService.saveSettings(settings);
    setState(() {});
  }

  Widget _buildListSection(String title, List<String> items, TextEditingController controller, VoidCallback onAdd, Function(int) onRemove) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: 'Add $title'),
              ),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
          ],
        ),
        const SizedBox(height: 10),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return ListTile(
            title: Text(value),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onRemove(index),
            ),
          );
        }).toList(),
        const SizedBox(height: 20),
      ],
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
            const Text('Expense Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(hintText: 'Add new category'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addCategory),
              ],
            ),
            const SizedBox(height: 10),
            ..._categories.map((cat) => ListTile(
              title: Text(cat.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteCategory(cat.id!),
              ),
            )),
            const Divider(height: 30),
            _buildListSection('Vehicle Designations', _vehicles, _vehicleController, _addVehicle, _removeVehicle),
            const Divider(height: 30),
            _buildListSection('Vendors / Subtrades', _vendors, _vendorController, _addVendor, _removeVendor),
          ],
        ),
      ),
    );
  }
}