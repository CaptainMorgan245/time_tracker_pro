// lib/client_and_project_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/project_repository.dart';

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
  bool _showInactive = false;

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

  void _showAddClientDialog(BuildContext context) {
    final clientNameController = TextEditingController();
    final contactPersonController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Client'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: clientNameController,
                    decoration: const InputDecoration(labelText: 'Client Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contactPersonController,
                    decoration: const InputDecoration(labelText: 'Contact Person'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final client = Client(
                    name: clientNameController.text.trim(),
                    contactPerson: contactPersonController.text.trim().isEmpty
                        ? null
                        : contactPersonController.text.trim(),
                    phoneNumber: phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                  );
                  await _clientRepo.insertClient(client);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddProjectDialog(BuildContext context) {
    final projectNameController = TextEditingController();
    final streetAddressController = TextEditingController();
    final cityController = TextEditingController();
    final regionController = TextEditingController();
    final postalCodeController = TextEditingController();
    final billedHourlyRateController = TextEditingController();
    final fixedPriceController = TextEditingController();
    final expenseMarkupController = TextEditingController(text: '15.0');
    final formKey = GlobalKey<FormState>();

    String selectedPricingModel = 'hourly';
    Client? selectedClient;
    List<Client> clients = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (clients.isEmpty) {
              _clientRepo.getClients().then((result) {
                setModalState(() => clients = result.where((c) => c.isActive).toList());
              });
            }
            return AlertDialog(
              title: const Text('Add Project'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: projectNameController,
                          decoration: const InputDecoration(labelText: 'Project Name'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Client>(
                          initialValue: selectedClient,
                          decoration: const InputDecoration(labelText: 'Client'),
                          items: clients
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          onChanged: (c) => setModalState(() => selectedClient = c),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPricingModel,
                          decoration: const InputDecoration(labelText: 'Pricing Model'),
                          items: const [
                            DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                            DropdownMenuItem(value: 'fixed', child: Text('Fixed Price')),
                            DropdownMenuItem(value: 'project_based', child: Text('Project Based')),
                          ],
                          onChanged: (v) => setModalState(() => selectedPricingModel = v!),
                        ),
                        const SizedBox(height: 12),
                        if (selectedPricingModel == 'hourly')
                          TextFormField(
                            controller: billedHourlyRateController,
                            decoration: const InputDecoration(labelText: 'Billed Hourly Rate'),
                            keyboardType: TextInputType.number,
                          ),
                        if (selectedPricingModel == 'fixed' || selectedPricingModel == 'project_based')
                          TextFormField(
                            controller: fixedPriceController,
                            decoration: const InputDecoration(labelText: 'Fixed Project Price'),
                            keyboardType: TextInputType.number,
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: streetAddressController,
                          decoration: const InputDecoration(labelText: 'Street Address'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: cityController,
                                decoration: const InputDecoration(labelText: 'City'),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: regionController,
                                decoration: const InputDecoration(labelText: 'Province'),
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: postalCodeController,
                          decoration: const InputDecoration(labelText: 'Postal Code'),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: expenseMarkupController,
                          decoration: const InputDecoration(labelText: 'Expense Markup %'),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8720C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final project = Project(
                        projectName: projectNameController.text.trim(),
                        clientId: selectedClient!.id!,
                        city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                        streetAddress: streetAddressController.text.trim().isEmpty
                            ? null
                            : streetAddressController.text.trim(),
                        region: regionController.text.trim().isEmpty ? null : regionController.text.trim(),
                        postalCode: postalCodeController.text.trim().isEmpty ? null : postalCodeController.text.trim(),
                        pricingModel: selectedPricingModel,
                        billedHourlyRate: double.tryParse(billedHourlyRateController.text),
                        fixedPrice: double.tryParse(fixedPriceController.text),
                        expenseMarkupPercentage: double.tryParse(expenseMarkupController.text) ?? 15.0,
                      );
                      await _projectRepo.insertProject(project);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadData();
                      }
                    }
                  },
                  child: const Text('Add Project'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditClientDialog(Client client) async {
    if (!client.isActive) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reactivate ${client.name}?'),
          content: const Text('This client will appear in active dropdowns again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reactivate'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final updatedClient = client.copyWith(isActive: true);
        _updateClient(updatedClient);
        if (mounted) {
          setState(() {
            _showInactive = false;
          });
        }
      }
      return;
    }

    final nameController = TextEditingController(text: client.name);
    final contactPersonController = TextEditingController(text: client.contactPerson);
    final phoneNumberController = TextEditingController(text: client.phoneNumber);

    final hasActiveProjects = _projects.any((p) => p.clientId == client.id && !p.isCompleted);
    final bool isDeactivationDisabled = client.isActive && hasActiveProjects;

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
            Tooltip(
              message: isDeactivationDisabled ? 'Complete all projects before deactivating' : '',
              child: TextButton(
                onPressed: isDeactivationDisabled ? null : () async {
                  if (client.isActive) {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Deactivate ${client.name}?'),
                        content: const Text('This client will no longer appear in active dropdowns.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Deactivate', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }
                  
                  final updatedClient = client.copyWith(isActive: !client.isActive);
                  _updateClient(updatedClient);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  client.isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(
                    color: isDeactivationDisabled
                        ? Colors.grey
                        : (client.isActive ? Colors.red : Colors.green)
                  ),
                ),
              ),
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

    var editCity = project.city ?? '';
    var editStreetAddress = project.streetAddress ?? '';
    var editRegion = project.region ?? '';
    var editPostalCode = project.postalCode ?? '';

    final editStreetAddressController = TextEditingController(text: project.streetAddress ?? '');
    final editRegionController = TextEditingController(text: project.region ?? '');
    final editPostalCodeController = TextEditingController(text: project.postalCode ?? '');

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
                        initialValue: selectedClientId,
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
                        initialValue: selectedPricingModel,
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
                        controller: editStreetAddressController,
                        decoration: const InputDecoration(labelText: 'Street Address'),
                        onChanged: (v) => editStreetAddress = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(text: project.city ?? ''),
                        decoration: const InputDecoration(labelText: 'City'),
                        onChanged: (v) => editCity = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: editRegionController,
                        decoration: const InputDecoration(labelText: 'Province'),
                        onChanged: (v) => editRegion = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: editPostalCodeController,
                        decoration: const InputDecoration(labelText: 'Postal Code'),
                        onChanged: (v) => editPostalCode = v,
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
                            this.setState(() {
                              _showInactive = false;
                            });
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
                          city: editCity,
                          streetAddress: editStreetAddress.trim().isEmpty ? null : editStreetAddress.trim(),
                          region: editRegion.trim().isEmpty ? null : editRegion.trim(),
                          postalCode: editPostalCode.trim().isEmpty ? null : editPostalCode.trim(),
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
    final isInactive = !client.isActive;
    return Card(
      color: isInactive ? Colors.grey.shade300 : null,
      child: ListTile(
        title: Text(
          client.name + (isInactive ? ' (Inactive)' : ''),
          style: theme.textTheme.titleMedium?.copyWith(
            color: isInactive ? Colors.grey.shade700 : null,
          ),
        ),
        subtitle: Text(
          'Contact: ${client.contactPerson ?? 'N/A'} | Phone: ${client.phoneNumber ?? 'N/A'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isInactive ? Colors.grey.shade600 : null,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: isInactive ? Colors.grey : Colors.blue),
          onPressed: () => _showEditClientDialog(client),
        ),
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

    final isCompleted = project.isCompleted;
    final tileColor = isCompleted ? Colors.grey.shade300 : null;

    return Card(
      color: tileColor,
      child: ListTile(
        title: Text(
          project.projectName + (isCompleted ? ' (Completed)' : ''),
          style: theme.textTheme.titleMedium?.copyWith(
            color: isCompleted ? Colors.grey.shade700 : null,
          ),
        ),
        subtitle: Text(
          'Client: ${_getClientName(project.clientId)} | $priceOrRate',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isCompleted ? Colors.grey.shade600 : null,
          ),
        ),
        trailing: IconButton(
            icon: Icon(Icons.edit, color: isCompleted ? Colors.grey : Colors.blue),
            onPressed: () => _showEditProjectDialog(project)),
        onTap: () => _showEditProjectDialog(project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeClients = _clients.where((c) => c.isActive).toList();
    final inactiveClients = _clients.where((c) => !c.isActive).toList();
    final activeProjects = _projects.where((p) => !p.isCompleted).toList();
    final completedProjects = _projects.where((p) => p.isCompleted).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Projects'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) { // WIDE LAYOUT
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8720C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                        ),
                        onPressed: () => setState(() => _showInactive = !_showInactive),
                        child: Text(_showInactive ? 'Show Active Clients and Projects' : 'Show Archived Clients and Projects'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.person_add, color: Colors.white),
                              label: const Text('Add Client'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _showAddClientDialog(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_business, color: Colors.white),
                              label: const Text('Add Project'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightGreen,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _showAddProjectDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: ListView(
                            children: [
                              if (!_showInactive) ...[
                                const Text('Current Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ...activeClients.map((client) => _buildClientListTile(client, theme)).toList(),
                              ] else ...[
                                const Text('Inactive Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ...inactiveClients.map((client) => _buildClientListTile(client, theme)).toList(),
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: ListView(
                            children: [
                              if (!_showInactive) ...[
                                const Text('Current Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ...activeProjects.map((project) => _buildProjectListTile(project, theme)).toList(),
                              ] else ...[
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8720C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                        ),
                        onPressed: () => setState(() => _showInactive = !_showInactive),
                        child: Text(_showInactive ? 'Show Active Clients and Projects' : 'Show Archived Clients and Projects'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.person_add, color: Colors.white),
                              label: const Text('Add Client'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _showAddClientDialog(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_business, color: Colors.white),
                              label: const Text('Add Project'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightGreen,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _showAddProjectDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 16),
                      if (!_showInactive) ...[
                        const Text('Current Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...activeClients.map((client) => _buildClientListTile(client, theme)).toList(),
                        const SizedBox(height: 32),
                        const Text('Current Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...activeProjects.map((project) => _buildProjectListTile(project, theme)).toList(),
                      ] else ...[
                        const Text('Inactive Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...inactiveClients.map((client) => _buildClientListTile(client, theme)).toList(),
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
