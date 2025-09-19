// lib/project_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/project_repository.dart';

class ProjectAddForm extends StatefulWidget {
  final List<Client> clients;
  final VoidCallback onProjectAdded;

  const ProjectAddForm({
    super.key,
    required this.clients,
    required this.onProjectAdded,
  });

  @override
  State<ProjectAddForm> createState() => _ProjectAddFormState();
}

class _ProjectAddFormState extends State<ProjectAddForm> {
  final ProjectRepository _projectRepo = ProjectRepository();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _billedHourlyRateController = TextEditingController();

  Client? _selectedClient;
  String _selectedPricingModel = 'hourly';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _projectNameController.dispose();
    _locationController.dispose();
    _billedHourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final projectName = _projectNameController.text.trim();
    final client = _selectedClient;

    if (projectName.isEmpty || client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project name and client are required')),
      );
      return;
    }

    final newProject = Project(
      projectName: projectName,
      clientId: client.id!,
      location: _locationController.text.isNotEmpty ? _locationController.text : null,
      pricingModel: _selectedPricingModel,
      billedHourlyRate: double.tryParse(_billedHourlyRateController.text),
    );

    setState(() => _isSubmitting = true);

    try {
      await _projectRepo.insertProject(newProject);
      _projectNameController.clear();
      _locationController.clear();
      _billedHourlyRateController.clear();
      setState(() {
        _selectedClient = null;
        _selectedPricingModel = 'hourly';
      });
      widget.onProjectAdded();
    } catch (e) {
      debugPrint('Error adding project: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding project: $e')),
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
                Expanded(
                  child: TextField(
                    controller: _projectNameController,
                    decoration: const InputDecoration(labelText: 'Project Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<Client>(
                    decoration: const InputDecoration(labelText: 'Client'),
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
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _billedHourlyRateController,
                    decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
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