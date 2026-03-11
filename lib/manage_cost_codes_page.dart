// lib/manage_cost_codes_page.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/cost_code_repository.dart';
import 'package:time_tracker_pro/models.dart';

// start class: ManageCostCodesPage
class ManageCostCodesPage extends StatefulWidget {
  const ManageCostCodesPage({Key? key}) : super(key: key);

  @override
  State<ManageCostCodesPage> createState() => _ManageCostCodesPageState();
}
// end class: ManageCostCodesPage

// start class: _ManageCostCodesPageState
class _ManageCostCodesPageState extends State<ManageCostCodesPage> {
  late CostCodeRepository _costCodeRepo;
  List<CostCode> _costCodes = [];
  bool _isLoading = true;

  // start method: initState
  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }
  // end method: initState

  // start method: _initializeRepository
  Future<void> _initializeRepository() async {
    final db = await DatabaseHelperV2.instance.database;
    _costCodeRepo = CostCodeRepository(db);
    await _loadCostCodes();
  }
  // end method: _initializeRepository

  // start method: _loadCostCodes
  Future<void> _loadCostCodes() async {
    setState(() => _isLoading = true);
    final costCodes = await _costCodeRepo.getAllCostCodes();
    setState(() {
      _costCodes = costCodes;
      _isLoading = false;
    });
  }
  // end method: _loadCostCodes

  // start method: _showEditDialog
  Future<void> _showEditDialog(CostCode? costCode) async {
    final isNew = costCode == null;
    final nameController = TextEditingController(text: costCode?.name ?? '');
    bool isBillable = costCode?.isBillable ?? false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? 'Add New Cost Code' : 'Edit Cost Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Cost Code Name',
                      hintText: 'e.g., Contract Work, Addendum, TBC',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Billable as Extra'),
                    subtitle: const Text('Include in extras invoice selection'),
                    value: isBillable,
                    onChanged: (value) {
                      setDialogState(() {
                        isBillable = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (!isNew)
                  TextButton(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Cost Code'),
                          content: Text('Are you sure you want to delete "${costCode.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _costCodeRepo.deleteCostCode(costCode.id!);
                        await _loadCostCodes();
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ElevatedButton(
                  child: Text(isNew ? 'Add' : 'Save'),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      if (isNew) {
                        await _costCodeRepo.insertCostCode(CostCode(
                          name: nameController.text.trim(),
                          isBillable: isBillable,
                        ));
                      } else {
                        await _costCodeRepo.updateCostCode(costCode.copyWith(
                          name: nameController.text.trim(),
                          isBillable: isBillable,
                        ));
                      }
                      await _loadCostCodes();
                      if (mounted) Navigator.of(context).pop();
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
  // end method: _showEditDialog

  // start method: build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cost Codes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AddCostCodeForm(onCostCodeAdded: _loadCostCodes),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                margin: EdgeInsets.zero,
                child: _costCodes.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No cost codes yet. Add one above.'),
                  ),
                )
                    : ListView.builder(
                  itemCount: _costCodes.length,
                  itemBuilder: (context, index) {
                    final costCode = _costCodes[index];
                    return ListTile(
                      leading: Icon(
                        costCode.isBillable ? Icons.receipt_long : Icons.label,
                        color: costCode.isBillable ? Colors.green : Colors.blueGrey,
                      ),
                      title: Text(costCode.name),
                      subtitle: costCode.isBillable ? const Text('Billable Extra', style: TextStyle(fontSize: 12)) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(costCode),
                      ),
                      onTap: () => _showEditDialog(costCode),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
// end method: build
}
// end class: _ManageCostCodesPageState

// start class: AddCostCodeForm
class AddCostCodeForm extends StatefulWidget {
  final VoidCallback onCostCodeAdded;

  const AddCostCodeForm({
    Key? key,
    required this.onCostCodeAdded,
  }) : super(key: key);

  @override
  State<AddCostCodeForm> createState() => _AddCostCodeFormState();
}
// end class: AddCostCodeForm

// start class: _AddCostCodeFormState
class _AddCostCodeFormState extends State<AddCostCodeForm> {
  late CostCodeRepository _costCodeRepo;
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;
  bool _isNewCodeBillable = false;

  // start method: initState
  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }
  // end method: initState

  // start method: _initializeRepository
  Future<void> _initializeRepository() async {
    final db = await DatabaseHelperV2.instance.database;
    _costCodeRepo = CostCodeRepository(db);
  }
  // end method: _initializeRepository

  // start method: dispose
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  // end method: dispose

  // start method: _submit
  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cost code name is required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _costCodeRepo.insertCostCode(CostCode(
        name: name,
        isBillable: _isNewCodeBillable,
      ));
      _nameController.clear();
      setState(() {
        _isNewCodeBillable = false;
      });
      widget.onCostCodeAdded();
    } catch (e) {
      debugPrint('Error adding cost code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding cost code: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  // end method: _submit

  // start method: build
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Add New Cost Code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About Cost Codes'),
                        content: const Text(
                            'Cost codes classify work against contract buckets.\n\n'
                                'Examples:\n'
                                '• Contract Work - Initial contracted work\n'
                                '• Addendum - Secondary contracts\n'
                                '• TBC - Billable extras to be charged\n'
                                '• No Charge - Warranty or goodwill work\n'
                                '• Internal - Own properties or overhead\n\n'
                                'Tag time entries and materials with cost codes to track which contract each hour and dollar belongs to.'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'What are cost codes?',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Cost Code Name',
                      hintText: 'e.g., Contract Work, Addendum, TBC',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Add Cost Code'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Billable as Extra'),
              subtitle: const Text('Include in extras invoice selection'),
              value: _isNewCodeBillable,
              onChanged: (value) => setState(() => _isNewCodeBillable = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
// end method: build
}
// end class: _AddCostCodeFormState
