// lib/client_and_project_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/settings_model.dart';

class ClientAndProjectAddForm extends StatefulWidget {
  final List<Client> clients;
  final VoidCallback onDataAdded;

  const ClientAndProjectAddForm({
    super.key,
    required this.clients,
    required this.onDataAdded,
  });

  @override
  State<ClientAndProjectAddForm> createState() => _ClientAndProjectAddFormState();
}

class _ClientAndProjectAddFormState extends State<ClientAndProjectAddForm> {
  final ClientRepository _clientRepo = ClientRepository();
  final ProjectRepository _projectRepo = ProjectRepository();

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _billedHourlyRateController = TextEditingController();
  final TextEditingController _fixedPriceController = TextEditingController();
  final TextEditingController _expenseMarkupController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _regionController = TextEditingController();
  final _postalCodeController = TextEditingController();

  Client? _selectedClient;
  String _selectedPricingModel = 'hourly';
  bool _isNewClient = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultMarkup();
  }

  Future<void> _loadDefaultMarkup() async {
    final settingsRows = await AppDatabase.instance.customSelect(
      'SELECT * FROM settings WHERE id = ?',
      variables: [Variable.withInt(1)],
    ).get();
    final settingsMap = settingsRows.map((r) => r.data).toList();
    final settings = settingsMap.isNotEmpty
        ? SettingsModel.fromMap(settingsMap.first)
        : SettingsModel();

    if (mounted) {
      setState(() {
        _expenseMarkupController.text = (settings.expenseMarkupPercentage).toString();
      });
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _contactPersonController.dispose();
    _phoneNumberController.dispose();
    _projectNameController.dispose();
    _locationController.dispose();
    _billedHourlyRateController.dispose();
    _fixedPriceController.dispose();
    _expenseMarkupController.dispose();
    _streetAddressController.dispose();
    _regionController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _clientNameController.clear();
    _contactPersonController.clear();
    _phoneNumberController.clear();
    _projectNameController.clear();
    _locationController.clear();
    _billedHourlyRateController.clear();
    _fixedPriceController.clear();
    _expenseMarkupController.clear();
    _streetAddressController.clear();
    _regionController.clear();
    _postalCodeController.clear();
    _loadDefaultMarkup();
    setState(() {
      _selectedClient = null;
      _isNewClient = false;
      _selectedPricingModel = 'hourly';
    });
  }

  Future<void> _submit() async {
    final projectName = _projectNameController.text.trim();
    if (projectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project name is required')),
      );
      return;
    }

    Client? client;
    if (_isNewClient) {
      final clientName = _clientNameController.text.trim();
      if (clientName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client name is required for a new client')),
        );
        return;
      }
      client = Client(
        name: clientName,
        contactPerson: _contactPersonController.text.isNotEmpty ? _contactPersonController.text : null,
        phoneNumber: _phoneNumberController.text.isNotEmpty ? _phoneNumberController.text : null,
      );
    } else {
      client = _selectedClient;
      if (client == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an existing client')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      int? clientId = client.id;
      if (_isNewClient) {
        clientId = await _clientRepo.insertClient(client);
      }

      if (clientId != null) {
        final newProject = Project(
          projectName: projectName,
          clientId: clientId,
          location: _locationController.text.isNotEmpty ? _locationController.text.trim() : null,
          streetAddress: _streetAddressController.text.trim().isEmpty
              ? null
              : _streetAddressController.text.trim(),
          region: _regionController.text.trim().isEmpty
              ? null
              : _regionController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          pricingModel: _selectedPricingModel,
          billedHourlyRate: _selectedPricingModel == 'hourly' && _billedHourlyRateController.text.isNotEmpty
              ? double.tryParse(_billedHourlyRateController.text)
              : null,
          fixedPrice: _selectedPricingModel != 'hourly' && _fixedPriceController.text.isNotEmpty
              ? double.tryParse(_fixedPriceController.text)
              : null,
          expenseMarkupPercentage: double.tryParse(_expenseMarkupController.text) ?? 15.0,
        );
        await _projectRepo.insertProject(newProject);
      }

      _resetForm();
      widget.onDataAdded();

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting data: $e')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeClients = widget.clients;
    const itemWidth = 250.0;
    // Fixed regex: removed accidental 'r' inside the string
    final phoneNumberFormatter = FilteringTextInputFormatter.allow(RegExp(r'[\d\.\-\(\)\s+]'));

    final ButtonStyle elevatedButtonStyle = ElevatedButton.styleFrom(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Add a new client?', style: TextStyle(fontWeight: FontWeight.w500)),
                Checkbox(
                  value: _isNewClient,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _isNewClient = newValue ?? false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              alignment: WrapAlignment.start,
              children: [
                if (_isNewClient) ...[
                  SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(labelText: 'New Client Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(labelText: 'Contact Person'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: _phoneNumberController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [phoneNumberFormatter],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: itemWidth,
                    child: DropdownButtonFormField<Client>(
                      decoration: const InputDecoration(labelText: 'Select an Existing Client'),
                      value: _selectedClient,
                      items: activeClients.map((client) {
                        return DropdownMenuItem<Client>(
                          value: client,
                          child: Text(client.name),
                        );
                      }).toList(),
                      onChanged: (Client? newValue) {
                        setState(() {
                          _selectedClient = newValue;
                        });
                      },
                    ),
                  ),
                ],
                SizedBox(
                  width: itemWidth,
                  child: TextField(
                    controller: _projectNameController,
                    decoration: const InputDecoration(labelText: 'Project Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Pricing Model'),
                    value: _selectedPricingModel,
                    items: const [
                      DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed Price')),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPricingModel = newValue!;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: TextFormField(
                    controller: _streetAddressController,
                    decoration: const InputDecoration(labelText: 'Street Address'),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'City'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: TextFormField(
                    controller: _regionController,
                    decoration: const InputDecoration(labelText: 'Province'),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(labelText: 'Postal Code'),
                  ),
                ),
                if (_selectedPricingModel == 'hourly')
                  SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: _billedHourlyRateController,
                      decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
                    ),
                  )
                else
                  SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: _fixedPriceController,
                      decoration: const InputDecoration(labelText: 'Fixed Project Price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
                    ),
                  ),
                SizedBox(
                  width: itemWidth,
                  child: TextField(
                    controller: _expenseMarkupController,
                    decoration: const InputDecoration(labelText: 'Expense Markup %'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 25,
                  child: ElevatedButton(
                    style: elevatedButtonStyle,
                    onPressed: _isSubmitting ? null : _resetForm,
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 75,
                  child: ElevatedButton(
                    style: elevatedButtonStyle,
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Add Project'),
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
