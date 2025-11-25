// lib/client_and_project_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/client_and_project_add_form.dart';

class ClientAndProjectScreen extends StatefulWidget {
  const ClientAndProjectScreen({super.key});

  @override
  State<ClientAndProjectScreen> createState() => _ClientAndProjectScreenState();
}

class _ClientAndProjectScreenState extends State<ClientAndProjectScreen> {
  final ClientRepository _clientRepo = ClientRepository();
  final ProjectRepository _projectRepo = ProjectRepository();

  List<Client> _clients = [];
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final clients = await _clientRepo.getClients();
      final projects = await _projectRepo.getProjects();
      if (mounted) {
        setState(() {
          _clients = clients;
          _projects = projects;
          _isLoading = false;
        });
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateClient(Client client) async {
    await _clientRepo.updateClient(client);
    _loadData();
  }

  Future<void> _updateProject(Project project) async {
    await _projectRepo.updateProject(project);
    _loadData();
  }

  Future<void> _deleteProject(int id) async {
    await _projectRepo.deleteProject(id);
    _loadData();
  }

  String _getClientName(int clientId) {
    try {
      return _clients.firstWhere((c) => c.id == clientId).name;
    } catch (e) {
      return 'Unknown';
    }
  }

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
              const SizedBox(height: 16),
              TextField(
                controller: contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneNumberController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: Text(client.isActive ? 'Deactivate' : 'Activate', style: TextStyle(color: client.isActive ? Colors.red : Colors.green)),
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

  // FIXED: Handles all three pricing models and aligns to the single fixedPrice DB field.
  Future<void> _showEditProjectDialog(Project project) async {
    final projectNameController = TextEditingController(text: project.projectName);
    final billedHourlyRateController = TextEditingController(text: project.billedHourlyRate?.toString());

    // Use a single controller for both 'fixed' and 'project_based' prices.
    final fixedPriceController = TextEditingController(text: project.fixedPrice?.toString());
    final expenseMarkupController = TextEditingController(text: project.expenseMarkupPercentage.toString());

    // FIX 1: Normalize the initial value from the database to prevent RSOD.
    String? selectedPricingModel = project.pricingModel;
    if (selectedPricingModel == 'fixed price') {
      selectedPricingModel = 'fixed';
    }

    int? selectedClientId = project.clientId;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Client'),
                        value: selectedClientId,
                        items: _clients.where((c) => c.isActive).map((client) {
                          return DropdownMenuItem<int>(
                            value: client.id,
                            child: Text(client.name),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            selectedClientId = newValue;
                          });
                        },
                      ),

                      // FIX 2: Added 'Project Based' option.
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Pricing Model'),
                        value: selectedPricingModel,
                        items: const [
                          DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                          DropdownMenuItem(value: 'fixed', child: Text('Fixed Price')),
                          DropdownMenuItem(value: 'project_based', child: Text('Project Based')),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedPricingModel = newValue;
                          });
                        },
                      ),

                      const SizedBox(height: 16),
                      if (selectedPricingModel == 'hourly')
                        TextField(
                          controller: billedHourlyRateController,
                          decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                          keyboardType: TextInputType.number,
                        )
                      // FIX 3: Use fixedPriceController for both 'fixed' and 'project_based'
                      else
                        SizedBox(
                          child: TextField(
                            controller: fixedPriceController,
                            decoration: InputDecoration(
                                labelText: selectedPricingModel == 'fixed'
                                    ? 'Fixed Project Price'
                                    : 'Project Based Price' // Dynamic label
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: expenseMarkupController,
                        decoration: const InputDecoration(labelText: 'Expense Markup %'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  FutureBuilder<bool>(
                    future: _projectRepo.hasAssociatedRecords(project.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const TextButton(onPressed: null, child: Text('...'));
                      }
                      final bool hasRecords = snapshot.data ?? false;

                      if (project.isCompleted) {
                        return TextButton(
                          child: const Text('Re-open', style: TextStyle(color: Colors.green)),
                          onPressed: () {
                            final toggledProject = project.copyWith(isCompleted: false);
                            _updateProject(toggledProject);
                            Navigator.of(context).pop();
                          },
                        );
                      }
                      if (hasRecords) {
                        return TextButton(
                          child: const Text('Complete', style: TextStyle(color: Colors.blue)),
                          onPressed: () {
                            final toggledProject = project.copyWith(isCompleted: true);
                            _updateProject(toggledProject);
                            Navigator.of(context).pop();
                          },
                        );
                      } else {
                        return TextButton(
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            _deleteProject(project.id!);
                            Navigator.of(context).pop();
                          },
                        );
                      }
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Save'),
                    onPressed: () {
                      if (projectNameController.text.isNotEmpty && selectedClientId != null) {

                        // FIX 4: Update the project saving logic to align with a single fixedPrice DB field.
                        double? hourlyRate = selectedPricingModel == 'hourly'
                            ? double.tryParse(billedHourlyRateController.text)
                            : null;

                        // Map both fixed and project_based models to the fixedPrice field.
                        double? newFixedPrice = (selectedPricingModel == 'fixed' || selectedPricingModel == 'project_based')
                            ? double.tryParse(fixedPriceController.text)
                            : null;

                        final updatedProject = project.copyWith(
                          projectName: projectNameController.text,
                          clientId: selectedClientId!,
                          pricingModel: selectedPricingModel,
                          billedHourlyRate: hourlyRate,
                          fixedPrice: newFixedPrice,
                          expenseMarkupPercentage: double.tryParse(expenseMarkupController.text) ?? 15.0,
                          // If 'projectBasedPrice' exists in the model, set it to null
                          // to explicitly only use fixedPrice, respecting the DB schema.
                          // projectBasedPrice: null,
                        );

                        _updateProject(updatedProject);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  Widget _buildClientListTile(Client client, ThemeData theme) {
    return Card(
      child: ListTile(
        title: Text(client.name, style: theme.textTheme.titleMedium),
        subtitle: Text('Contact: ${client.contactPerson ?? 'N/A'} | Phone: ${client.phoneNumber ?? 'N/A'}', style: theme.textTheme.bodyMedium),
        trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditClientDialog(client)),
        onTap: () => _showEditClientDialog(client),
      ),
    );
  }

  Widget _buildProjectListTile(Project project, ThemeData theme) {
    String priceOrRate;
    if (project.pricingModel == 'hourly') {
      priceOrRate = '\$${project.billedHourlyRate?.toStringAsFixed(2) ?? '0.00'}/hr';
    } else {
      // Use fixedPrice for both fixed and project based models
      final price = project.fixedPrice;
      final modelLabel = project.pricingModel == 'fixed' ? 'Fixed' : 'Project Based';
      priceOrRate = '\$${price?.toStringAsFixed(2) ?? '0.00'} $modelLabel';
    }

    // FIX 5: Removed the strikethrough logic entirely.
    final tileColor = project.isCompleted ? Colors.grey.shade300 : null;

    return Card(
      color: tileColor,
      child: ListTile(
        title: Text(project.projectName, style: theme.textTheme.titleMedium),
        subtitle: Text('Client: ${_getClientName(project.clientId)} | $priceOrRate', style: theme.textTheme.bodyMedium),
        trailing: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showEditProjectDialog(project)),
        onTap: () => _showEditProjectDialog(project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeClients = _clients.where((c) => c.isActive).toList();
    final activeProjects = _projects.where((p) => !p.isCompleted).toList();
    final completedProjects = _projects.where((p) => p.isCompleted).toList();
    final theme = Theme.of(context);

    // FIX 6: Re-implemented the main widget tree to enforce the static form/scrolling list requirement.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Projects'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) { // WIDE LAYOUT
            return Column( // Use Column to enable static top content and expandable scrolling content
              children: [
                // 1. STATIC FORM - Top section, always visible
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClientAndProjectAddForm(
                    clients: activeClients,
                    onDataAdded: _loadData,
                  ),
                ),

                // 2. SCROLLING LISTS - Expanded to fill the remaining space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: ListView( // Scrolling List
                            children: [
                              const Text('Current Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ...activeClients.map((client) => _buildClientListTile(client, theme)).toList(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: ListView( // Scrolling List
                            children: [
                              const Text('Current Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ...activeProjects.map((project) => _buildProjectListTile(project, theme)).toList(),
                              if (completedProjects.isNotEmpty)...[
                                const SizedBox(height: 32),
                                const Text('Completed Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ...completedProjects.map((project) => _buildProjectListTile(project, theme)).toList(),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else { // NARROW LAYOUT
            return Column( // Use Column to enable static top content and expandable scrolling content
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. STATIC FORM - Top section, always visible
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClientAndProjectAddForm(
                    clients: activeClients,
                    onDataAdded: _loadData,
                  ),
                ),

                // 2. SCROLLING LISTS - Expanded to fill the remaining space
                Expanded(
                  child: ListView( // Single Scrolling List
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 16),
                      const Text('Current Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ...activeClients.map((client) => _buildClientListTile(client, theme)).toList(),
                      const SizedBox(height: 32),
                      const Text('Current Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ...activeProjects.map((project) => _buildProjectListTile(project, theme)).toList(),
                      if (completedProjects.isNotEmpty)...[
                        const SizedBox(height: 32),
                        const Text('Completed Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...completedProjects.map((project) => _buildProjectListTile(project, theme)).toList(),
                      ]
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
