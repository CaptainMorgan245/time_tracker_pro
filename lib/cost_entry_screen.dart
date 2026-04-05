// lib/cost_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/cost_record_form.dart';
import 'package:time_tracker_pro/project_repository.dart';
import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/cost_code_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:intl/intl.dart';

class CostRecordFormTopRow extends StatelessWidget {
  final GlobalKey<CostRecordFormState> formStateKey;
  final ValueNotifier<List<Project>> filteredProjectsNotifier;
  final ValueNotifier<List<String>> expenseCategoriesNotifier;
  final ValueNotifier<bool> isCompanyExpenseNotifier;
  final String currentItemName;
  final List<Client> clients;
  final int? selectedClientId;
  final int? selectedProjectId;
  final Function(int?) onClientChanged;
  final Function(int?) onProjectChanged;
  final int? internalProjectId;
  final int? companyClientId;

  const CostRecordFormTopRow({
    super.key,
    required this.formStateKey,
    required this.filteredProjectsNotifier,
    required this.expenseCategoriesNotifier,
    required this.isCompanyExpenseNotifier,
    required this.currentItemName,
    required this.clients,
    required this.selectedClientId,
    required this.selectedProjectId,
    required this.onClientChanged,
    required this.onProjectChanged,
    required this.internalProjectId,
    required this.companyClientId,
  });

  String _getProjectDisplayName(Project project) {
    if (project.isInternal) return 'Internal Company Project';

    final name = project.projectName;
    final sameNameCount = filteredProjectsNotifier.value.where((p) => p.projectName == name).length;

    if (sameNameCount > 1) {
      final client = clients.firstWhere((c) => c.id == project.clientId, orElse: () => Client(name: 'Unknown'));
      return '$name (${client.name})';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets consistentContentPadding = EdgeInsets.fromLTRB(10, 14, 8, 8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: DropdownButtonFormField<int?>(
                    decoration: InputDecoration(
                      labelText: 'Client',
                      labelStyle: const TextStyle(fontSize: 12),
                      contentPadding: consistentContentPadding,
                    ),
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                    value: selectedClientId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Clients')),
                      ...clients.map((client) => DropdownMenuItem<int?>(
                        value: client.id,
                        child: Text(client.name),
                      )),
                    ],
                    onChanged: onClientChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isCompanyExpenseNotifier,
                    builder: (context, isCompanyExpense, _) {
                      return ValueListenableBuilder<List<Project>>(
                        valueListenable: filteredProjectsNotifier,
                        builder: (context, projects, _) {
                          final isProjectDropdownEnabled = !isCompanyExpense;

                          // Ensure project list is unique by ID to prevent dropdown assertion error
                          final Map<int, Project> uniqueProjects = {};
                          for (var p in projects) {
                            if (p.id != null) uniqueProjects[p.id!] = p;
                          }
                          final uniqueProjectList = uniqueProjects.values.toList();

                          return DropdownButtonFormField<int?>(
                            decoration: InputDecoration(
                              labelText: 'Project',
                              labelStyle: const TextStyle(fontSize: 12),
                              suffixIcon: isProjectDropdownEnabled ? const Padding(padding: EdgeInsets.only(top: 12), child: Text('*', style: TextStyle(color: Colors.red))) : null,
                              contentPadding: consistentContentPadding,
                            ),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            isDense: true,
                            value: selectedProjectId,
                            onChanged: isProjectDropdownEnabled ? onProjectChanged : null,
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Projects', style: TextStyle(fontStyle: FontStyle.italic)),
                              ),
                              ...uniqueProjectList.map((project) {
                                return DropdownMenuItem<int?>(
                                  value: project.id,
                                  child: Text(_getProjectDisplayName(project), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                flex: 5,
                child: SizedBox(
                  height: 40,
                  child: TextFormField(
                    key: ValueKey('itemName_${currentItemName}_${formStateKey.hashCode}'),
                    initialValue: currentItemName,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      labelStyle: const TextStyle(fontSize: 12),
                      contentPadding: consistentContentPadding,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      formStateKey.currentState?.setItemName(value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: expenseCategoriesNotifier,
                    builder: (context, categories, _) {
                      final currentCategory = formStateKey.currentState?.selectedExpenseCategory;
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          labelStyle: const TextStyle(fontSize: 12),
                          contentPadding: consistentContentPadding,
                        ),
                        style: const TextStyle(fontSize: 13, color: Colors.black),
                        value: currentCategory,
                        items: categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (String? newValue) {
                          formStateKey.currentState?.setState(() {
                            formStateKey.currentState!.selectedExpenseCategory = newValue;
                            formStateKey.currentState!.isFuelCategory = (newValue == 'Fuel');
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: isCompanyExpenseNotifier,
                            builder: (context, isCompanyExpense, _) {
                              return Checkbox(
                                value: isCompanyExpense,
                                onChanged: (bool? newValue) {
                                  isCompanyExpenseNotifier.value = newValue ?? false;
                                  if (isCompanyExpenseNotifier.value) {
                                    onClientChanged(companyClientId);
                                    onProjectChanged(internalProjectId);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const Text('Vehicle Exp.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                      ],
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
}

class CostEntryScreen extends StatefulWidget {
  const CostEntryScreen({super.key});

  @override
  State<CostEntryScreen> createState() => _CostEntryScreenState();
}

class _CostEntryScreenState extends State<CostEntryScreen> {
  final _formStateKey = GlobalKey<CostRecordFormState>();
  final _projectRepo = ProjectRepository();
  final _clientRepo = ClientRepository();
  CostCodeRepository? _costCodeRepo;

  bool _isLoading = true;
  int _refreshKey = 0;

  final ValueNotifier<List<Project>> _filteredProjectsNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _expenseCategoriesNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _vendorsNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> _vehicleDesignationsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isCompanyExpenseNotifier = ValueNotifier(false);
  final ValueNotifier<List<CostCode>> _costCodesNotifier = ValueNotifier([]);

  List<Project> _allProjects = [];
  List<Client> _clients = [];
  int? _selectedClientId;
  int? _selectedProjectId;
  int? _internalProjectId;
  int? _companyClientId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _filteredProjectsNotifier.dispose();
    _expenseCategoriesNotifier.dispose();
    _vendorsNotifier.dispose();
    _vehicleDesignationsNotifier.dispose();
    _isCompanyExpenseNotifier.dispose();
    _costCodesNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _costCodeRepo ??= CostCodeRepository();
      final phases = await _costCodeRepo!.getAllCostCodes();
      _costCodesNotifier.value = phases;

      final rows = await AppDatabase.instance
          .customSelect('SELECT * FROM settings WHERE id = ?', variables: [Variable.withInt(1)])
          .get();
      final maps = rows.map((r) => r.data).toList();
      final settings = maps.isNotEmpty ? SettingsModel.fromMap(maps.first) : SettingsModel();

      final dataFutures = [
        _projectRepo.getProjects(),
        AppDatabase.instance.getExpenseCategoriesV2(),
        _clientRepo.getClients()
      ];
      final results = await Future.wait(dataFutures);
      _allProjects = results[0] as List<Project>;
      final categories = results[1] as List<ExpenseCategory>;
      _clients = results[2] as List<Client>;

      if (!mounted) return;
      _expenseCategoriesNotifier.value = categories.map((c) => c.name).toList();
      _vendorsNotifier.value = List<String>.from(settings.vendors);
      _vehicleDesignationsNotifier.value = List<String>.from(settings.vehicleDesignations);

      final internalIds = await AppDatabase.instance.getInternalRecordIds();
      _internalProjectId = internalIds['internalProjectId'];
      _companyClientId = internalIds['companyClientId'];

      _updateFilteredProjectsList();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateFilteredProjectsList() {
    List<Project> filtered = _allProjects;

    if (_selectedClientId == _companyClientId && _companyClientId != null) {
      // Company Expenses — show internal projects only
      filtered = filtered.where((p) => p.isInternal).toList();
    } else if (_selectedClientId != null) {
      // Real client — show that client's active projects only
      filtered = filtered.where((p) => 
        p.clientId == _selectedClientId && !p.isCompleted).toList();
    } else {
      // No client selected — show all active non-internal projects
      filtered = filtered.where((p) => 
        !p.isCompleted && !p.isInternal).toList();
    }

    _filteredProjectsNotifier.value = filtered;

    if (_selectedProjectId != null && 
        !filtered.any((p) => p.id == _selectedProjectId)) {
      setState(() {
        _selectedProjectId = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formStateKey.currentState?.setSelectedProjectId(null);
      });
    }
  }

  void _onClientChanged(int? clientId) {
    setState(() {
      _selectedClientId = clientId;
      _selectedProjectId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formStateKey.currentState?.setSelectedProjectId(null);
    });
    _updateFilteredProjectsList();
  }

  void _onProjectChanged(int? projectId) {
    setState(() {
      _selectedProjectId = projectId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formStateKey.currentState?.setSelectedProjectId(projectId);
    });
  }

  void _showEditModal(JobMaterials record) {
    final editFormKey = GlobalKey<CostRecordFormState>();
    final editCompanyExpenseNotifier = ValueNotifier<bool>(record.isCompanyExpense);
    final editProjectsNotifier = ValueNotifier<List<Project>>(_allProjects);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text("Edit Record", style: TextStyle(fontSize: 16)),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Vehicle checkbox row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: editCompanyExpenseNotifier,
                            builder: (context, isCompanyExpense, _) {
                              return Checkbox(
                                value: isCompanyExpense,
                                onChanged: (bool? newValue) {
                                  editCompanyExpenseNotifier.value = newValue ?? false;
                                  if (editCompanyExpenseNotifier.value) {
                                    editFormKey.currentState?.setSelectedProjectId(_internalProjectId);
                                  }
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              );
                            },
                          ),
                          const Text('Vehicle Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          const Icon(Icons.help_outline, size: 14, color: Colors.blueGrey),
                        ],
                      ),
                    ],
                  ),
                ),
                CostRecordForm(
                  key: editFormKey,
                  availableProjectsNotifier: editProjectsNotifier,
                  expenseCategoriesNotifier: _expenseCategoriesNotifier,
                  vendorsNotifier: _vendorsNotifier,
                  vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                  costCodesNotifier: _costCodesNotifier,
                  onAddExpense: (expense, isEdit) async {
                    await _handleCostSubmission(expense, isEdit);
                    if (context.mounted) Navigator.pop(context);
                  },
                  onProjectFilterToggle: (_) {},
                  onClearForm: () => Navigator.pop(context),
                  isEditing: true,
                  onCompanyExpenseToggle: editCompanyExpenseNotifier,
                  internalProjectId: _internalProjectId,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Populate form data after dialog builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editFormKey.currentState != null) {
        editFormKey.currentState!.populateForm(record);
      }
    });
  }

  void _handleClearOrCancel() {
    _formStateKey.currentState?.resetForm();
    setState(() {
      _isCompanyExpenseNotifier.value = false;
      _selectedClientId = null;
      _selectedProjectId = null;
    });
    _updateFilteredProjectsList();
  }

  Future<void> _handleCostSubmission(JobMaterials expense, bool isEditing) async {
    if (isEditing) {
      await AppDatabase.instance.updateMaterialV2(expense);
    } else {
      await AppDatabase.instance.addMaterialV2(expense);
    }
    setState(() => _refreshKey++);
    if (!isEditing) _handleClearOrCancel();
  }

  Future<void> _handleDeleteExpense(int id) async {
    await AppDatabase.instance.deleteRecordV2(id: id, fromTable: 'materials');
    setState(() => _refreshKey++);
  }

  String _getProjectNameById(int projectId) {
    try {
      return _allProjects.firstWhere((p) => p.id == projectId).projectName;
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: CostRecordFormTopRow(
                formStateKey: _formStateKey,
                filteredProjectsNotifier: _filteredProjectsNotifier,
                expenseCategoriesNotifier: _expenseCategoriesNotifier,
                isCompanyExpenseNotifier: _isCompanyExpenseNotifier,
                currentItemName: _formStateKey.currentState?.getCurrentItemName() ?? '',
                clients: _clients,
                selectedClientId: _selectedClientId,
                selectedProjectId: _selectedProjectId,
                onClientChanged: _onClientChanged,
                onProjectChanged: _onProjectChanged,
                internalProjectId: _internalProjectId,
                companyClientId: _companyClientId,
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: CostRecordForm(
                key: _formStateKey,
                availableProjectsNotifier: _filteredProjectsNotifier,
                expenseCategoriesNotifier: _expenseCategoriesNotifier,
                vendorsNotifier: _vendorsNotifier,
                vehicleDesignationsNotifier: _vehicleDesignationsNotifier,
                costCodesNotifier: _costCodesNotifier,
                onAddExpense: _handleCostSubmission,
                onProjectFilterToggle: (_) {},
                onClearForm: _handleClearOrCancel,
                isEditing: false,
                onCompanyExpenseToggle: _isCompanyExpenseNotifier,
                internalProjectId: _internalProjectId,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<JobMaterials>>(
                key: ValueKey(_refreshKey),
                future: AppDatabase.instance.getCostEntryMaterials(
                  false, // showCompleted is no longer used for bulk loading here
                  _allProjects,
                  selectedProjectId: _selectedProjectId,
                ),
                builder: (context, snapshot) {
                  var records = snapshot.data ?? [];

                  // Secondary filter for Clients (especially when Project is 'All')
                  if (_selectedClientId != null) {
                    records = records.where((r) {
                      final project = _allProjects.firstWhere(
                              (p) => p.id == r.projectId,
                          orElse: () => Project(clientId: -1, projectName: '', pricingModel: '')
                      );
                      
                      if (_selectedClientId == _companyClientId && _companyClientId != null) return project.isInternal;
                      
                      return project.clientId == _selectedClientId;
                    }).toList();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 80.0),
                    itemCount: records.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final projectName = _getProjectNameById(record.projectId);
                      final vendorName = record.vendorOrSubtrade ?? 'Unknown';
                      final costAmount = NumberFormat.currency(locale: 'en_US', symbol: '\$').format(record.cost);
                      final dateStr = DateFormat('MM/dd').format(record.purchaseDate);

                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 1,
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          title: Text(
                            '$dateStr | $projectName | $costAmount',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${record.itemName} | $vendorName',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showEditModal(record),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _handleDeleteExpense(record.id!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
