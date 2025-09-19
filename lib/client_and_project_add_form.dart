// lib/client_and_project_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/project_repository.dart';

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

  Client? _selectedClient;
  String _selectedPricingModel = 'hourly';
  bool _isNewClient = false;
  bool _isSubmitting = false;

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
          location: _locationController.text.isNotEmpty ? _locationController.text : null,
          pricingModel: _selectedPricingModel,
          billedHourlyRate: double.tryParse(_billedHourlyRateController.text),
        );
        await _projectRepo.insertProject(newProject);
      }

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

  @override
  Widget build(BuildContext context) {
    final activeClients = widget.clients.where((c) => c.isActive).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Add a new client?'),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0, // horizontal spacing
              runSpacing: 8.0, // vertical spacing
              children: [
                if (_isNewClient) ...[
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(labelText: 'New Client Name'),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(labelText: 'Contact Person'),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _phoneNumberController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: 200,
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
                  width: 200,
                  child: TextField(
                    controller: _projectNameController,
                    decoration: const InputDecoration(labelText: 'Project Name'),
                  ),
                ),
                SizedBox(
                  width: 200,
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
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _billedHourlyRateController,
                    decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting ? const CircularProgressIndicator() : const Text('Add Project'),
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