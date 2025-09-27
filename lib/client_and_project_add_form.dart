// lib/client_and_project_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/input_formatters.dart';
import 'package:flutter/services.dart'; // Required for input formatters

// start class: ClientAndProjectAddForm
class ClientAndProjectAddForm extends StatefulWidget {
  final List<Client> clients;
  final VoidCallback onDataAdded;

  // start method: constructor
  const ClientAndProjectAddForm({
    super.key,
    required this.clients,
    required this.onDataAdded,
  });
  // end method: constructor

  @override
  State<ClientAndProjectAddForm> createState() => _ClientAndProjectAddFormState();
}
// end class: ClientAndProjectAddForm

// start class: _ClientAndProjectAddFormState
class _ClientAndProjectAddFormState extends State<ClientAndProjectAddForm> {
  final ClientRepository _clientRepo = ClientRepository();
  // FIX: Changed _ProjectRepository() to ProjectRepository()
  final ProjectRepository _projectRepo = ProjectRepository();

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _billedHourlyRateController = TextEditingController();

  Client? _selectedClient;
  String _selectedPricingModel = 'hourly';
  bool _isNewClient = false;
  bool _isSubmitting = false;

  // start method: dispose
  @override
  void dispose() {
    _clientNameController.dispose();
    _contactPersonController.dispose();
    _phoneNumberController.dispose();
    _projectNameController.dispose();
    _locationController.dispose();
    _billedHourlyRateController.dispose();
    super.dispose();
  }
  // end method: dispose

  // start method: _submit
  Future<void> _submit() async {
    // ... (Submission logic remains the same)
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
          location: _locationController.text.isNotEmpty ? _locationController.text : null,
          pricingModel: _selectedPricingModel,
          billedHourlyRate: double.tryParse(_billedHourlyRateController.text),
        );
        await _projectRepo.insertProject(newProject);
      }

      // Clear controllers after successful submission
      _clientNameController.clear();
      _contactPersonController.clear();
      _phoneNumberController.clear();
      _projectNameController.clear();
      _locationController.clear();
      _billedHourlyRateController.clear();

      setState(() {
        _isNewClient = false;
        _selectedClient = null;
        _selectedPricingModel = 'hourly';
      });
      widget.onDataAdded();
    } catch (e) {
      debugPrint('Error adding data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding data: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  // end method: _submit

  // start method: _buildFormInputWrapper
  /// Helper to enforce consistent card styling/padding for individual TextFields,
  /// matching the visual feel of the AppInputFormCard.
  Widget _buildFormInputWrapper({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child,
      ),
    );
  }
  // end method: _buildFormInputWrapper

  // start method: build
  @override
  Widget build(BuildContext context) {
    final activeClients = widget.clients.where((c) => c.isActive).toList();
    const itemWidth = 250.0; // Standardized width for all form fields

    // Define formatters once
    final capitalizationFormatter = CapitalizeEachWordInputFormatter();
    // Formatter allows digits, the dot (.), AND the dash (-).
    final phoneNumberFormatter = FilteringTextInputFormatter.allow(RegExp(r'[\d\.\-]'));


    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Standardized heading
            const SizedBox(height: 12),
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
              spacing: 16.0, // Standardized spacing
              runSpacing: 16.0,
              alignment: WrapAlignment.start,
              children: [
                if (_isNewClient) ...[
                  // New Client Input Fields
                  SizedBox(
                    width: itemWidth,
                    child: _buildFormInputWrapper(
                      child: TextField(
                        controller: _clientNameController,
                        decoration: const InputDecoration(labelText: 'New Client Name'),
                        inputFormatters: [capitalizationFormatter],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildFormInputWrapper(
                      child: TextField(
                        controller: _contactPersonController,
                        decoration: const InputDecoration(labelText: 'Contact Person'),
                        inputFormatters: [capitalizationFormatter],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildFormInputWrapper(
                      child: TextField(
                        controller: _phoneNumberController,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                        // FINAL BEST SHOT: Guarantees numeric keypad, dot, and often the minus/dash sign.
                        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                        // Restrict input to numbers, dot, and dash
                        inputFormatters: [phoneNumberFormatter],
                      ),
                    ),
                  ),
                ] else ...[
                  // Existing Client Dropdown
                  SizedBox(
                    width: itemWidth,
                    child: _buildFormInputWrapper(
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
                  ),
                ],

                // Project Input Fields
                SizedBox(
                  width: itemWidth,
                  child: _buildFormInputWrapper(
                    child: TextField(
                      controller: _projectNameController,
                      decoration: const InputDecoration(labelText: 'Project Name'),
                      inputFormatters: [capitalizationFormatter],
                    ),
                  ),
                ),
                // Pricing Model Dropdown
                SizedBox(
                  width: itemWidth,
                  child: _buildFormInputWrapper(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Pricing Model'),
                      value: _selectedPricingModel,
                      items: const [
                        DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                        DropdownMenuItem(value: 'fixed price', child: Text('Fixed Price')),
                        DropdownMenuItem(value: 'project based', child: Text('Project Based')),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPricingModel = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildFormInputWrapper(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                      inputFormatters: [capitalizationFormatter],
                    ),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildFormInputWrapper(
                    child: TextField(
                      controller: _billedHourlyRateController,
                      decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                // Submission Button
                SizedBox(
                  width: itemWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting ? const CircularProgressIndicator() : const Text('Add Project'),
                      ),
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
// end method: build
}
// end class: _ClientAndProjectAddFormState
