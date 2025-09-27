// lib/client_and_project_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/client_and_project_add_form.dart';
// Import reusable components for structural consistency
import 'package:time_tracker_pro/widgets/app_input_form_card.dart';
import 'package:time_tracker_pro/widgets/app_setting_list_card.dart';

// start class: ClientAndProjectScreen
class ClientAndProjectScreen extends StatefulWidget {
  const ClientAndProjectScreen({super.key});

  @override
  State<ClientAndProjectScreen> createState() => _ClientAndProjectScreenState();
}
// end class: ClientAndProjectScreen

// start class: _ClientAndProjectScreenState
class _ClientAndProjectScreenState extends State<ClientAndProjectScreen> {
  final ClientRepository _clientRepo = ClientRepository();
  final ProjectRepository _projectRepo = ProjectRepository();

  List<Client> _clients = [];
  List<Project> _projects = [];
  bool _isLoading = true;

  // start method: initState
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  // end method: initState

  // start method: _loadData
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final clients = await _clientRepo.getClients();
    final projects = await _projectRepo.getProjects();
    setState(() {
      _clients = clients;
      _projects = projects;
      _isLoading = false;
    });
  }
  // end method: _loadData

  // start method: _updateClient
  Future<void> _updateClient(Client client) async {
    await _clientRepo.updateClient(client);
    _loadData();
  }
  // end method: _updateClient

  // start method: _updateProject
  Future<void> _updateProject(Project project) async {
    await _projectRepo.updateProject(project);
    _loadData();
  }
  // end method: _updateProject

  // start method: _getClientName
  String _getClientName(int clientId) {
    try {
      return _clients.firstWhere((c) => c.id == clientId).name;
    } catch (e) {
      return 'Unknown';
    }
  }
  // end method: _getClientName

  // start method: _showEditClientDialog
  Future<void> _showEditClientDialog(Client client) async {
    final nameController = TextEditingController(text: client.name);
    final contactPersonController = TextEditingController(text: client.contactPerson);
    final phoneNumberController = TextEditingController(text: client.phoneNumber);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Client Name'),
              ),
              TextField(
                controller: contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              TextField(
                controller: phoneNumberController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(client.isActive ? 'Delete' : 'Activate', style: TextStyle(color: client.isActive ? Colors.red : Colors.green)),
              onPressed: () {
                final updatedClient = client.copyWith(isActive: !client.isActive);
                _updateClient(updatedClient);
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final updatedClient = client.copyWith(
                    name: nameController.text,
                    contactPerson: contactPersonController.text.isNotEmpty ? contactPersonController.text : null,
                    phoneNumber: phoneNumberController.text.isNotEmpty ? phoneNumberController.text : null,
                  );
                  _updateClient(updatedClient);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // end method: _showEditClientDialog

  // start method: _showEditProjectDialog
  Future<void> _showEditProjectDialog(Project project) async {
    final projectNameController = TextEditingController(text: project.projectName);
    final locationController = TextEditingController(text: project.location);
    final billedHourlyRateController = TextEditingController(text: project.billedHourlyRate?.toString());

    String? selectedPricingModel = project.pricingModel;
    int? selectedClientId = project.clientId;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: projectNameController,
                  decoration: const InputDecoration(labelText: 'Project Name'),
                ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Client'),
                  value: selectedClientId,
                  items: _clients.map((client) {
                    return DropdownMenuItem<int>(
                      value: client.id,
                      child: Text(client.name),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    selectedClientId = newValue;
                  },
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Pricing Model'),
                  value: selectedPricingModel,
                  items: const [
                    DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                    DropdownMenuItem(value: 'fixed price', child: Text('Fixed Price')),
                    DropdownMenuItem(value: 'project based', child: Text('Project Based')),
                  ],
                  onChanged: (String? newValue) {
                    selectedPricingModel = newValue;
                  },
                ),
                TextField(
                  controller: billedHourlyRateController,
                  decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(project.isCompleted ? 'Re-open' : 'Complete', style: TextStyle(color: project.isCompleted ? Colors.green : Colors.red)),
              onPressed: () {
                final updatedProject = project.copyWith(isCompleted: !project.isCompleted);
                _updateProject(updatedProject);
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (projectNameController.text.isNotEmpty && selectedClientId != null) {
                  final updatedProject = project.copyWith(
                    projectName: projectNameController.text,
                    clientId: selectedClientId!,
                    location: locationController.text.isNotEmpty ? locationController.text : null,
                    pricingModel: selectedPricingModel,
                    billedHourlyRate: double.tryParse(billedHourlyRateController.text),
                  );
                  _updateProject(updatedProject);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // end method: _showEditProjectDialog

  // start method: _buildClientListTile
  /// Helper widget to build a consistent ListTile for the Client list.
  Widget _buildClientListTile(Client client, ThemeData theme) {
    return Card(
      child: ListTile(
        title: Text(
          client.name,
          style: theme.textTheme.titleMedium, // Adjusted for consistency
        ),
        subtitle: Text(
          'Contact: ${client.contactPerson ?? 'N/A'} | Phone: ${client.phoneNumber ?? 'N/A'}',
          style: theme.textTheme.bodyMedium, // Adjusted for consistency
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue), // Standardized icon color
          onPressed: () => _showEditClientDialog(client),
        ),
        onTap: () => _showEditClientDialog(client),
      ),
    );
  }
  // end method: _buildClientListTile

  // start method: _buildProjectListTile
  /// Helper widget to build a consistent ListTile for the Project list.
  Widget _buildProjectListTile(Project project, ThemeData theme) {
    return Card(
      child: ListTile(
        title: Text(
          project.projectName,
          style: theme.textTheme.titleMedium, // Adjusted for consistency
        ),
        subtitle: Text(
          'Client: ${_getClientName(project.clientId)} | Pricing: ${project.pricingModel} | Rate: \$${project.billedHourlyRate?.toStringAsFixed(2) ?? 'N/A'}',
          style: theme.textTheme.bodyMedium, // Adjusted for consistency
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue), // Standardized icon color
          onPressed: () => _showEditProjectDialog(project),
        ),
        onTap: () => _showEditProjectDialog(project),
      ),
    );
  }
  // end method: _buildProjectListTile

  // start method: build
  @override
  Widget build(BuildContext context) {
    final activeClients = _clients.where((c) => c.isActive).toList();
    final activeProjects = _projects.where((p) => !p.isCompleted).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Projects'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          // start logic: wide screen layout
          if (constraints.maxWidth > 800) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ClientAndProjectAddForm is a separate component and remains untouched here
                  ClientAndProjectAddForm(
                    clients: _clients.where((c) => c.isActive).toList(),
                    onDataAdded: _loadData,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Clients',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Consistent heading size
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeClients.length,
                              itemBuilder: (context, index) {
                                return _buildClientListTile(activeClients[index], theme);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Projects',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Consistent heading size
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeProjects.length,
                              itemBuilder: (context, index) {
                                return _buildProjectListTile(activeProjects[index], theme);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          // end logic: wide screen layout

          // start logic: narrow screen layout
          else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClientAndProjectAddForm(
                    clients: _clients.where((c) => c.isActive).toList(),
                    onDataAdded: _loadData,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Current Clients',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Consistent heading size
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeClients.length,
                    itemBuilder: (context, index) {
                      return _buildClientListTile(activeClients[index], theme);
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Current Projects',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Consistent heading size
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeProjects.length,
                    itemBuilder: (context, index) {
                      return _buildProjectListTile(activeProjects[index], theme);
                    },
                  ),
                ],
              ),
            );
          }
          // end logic: narrow screen layout
        },
      ),
    );
  }
// end method: build
}
// end class: _ClientAndProjectScreenState
