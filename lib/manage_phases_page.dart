// lib/manage_phases_page.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/phase_repository.dart';
import 'package:time_tracker_pro/models.dart';

// start class: ManagePhasesPage
class ManagePhasesPage extends StatefulWidget {
  const ManagePhasesPage({Key? key}) : super(key: key);

  @override
  State<ManagePhasesPage> createState() => _ManagePhasesPageState();
}
// end class: ManagePhasesPage

// start class: _ManagePhasesPageState
class _ManagePhasesPageState extends State<ManagePhasesPage> {
  late PhaseRepository _phaseRepo;
  List<Phase> _phases = [];
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
    _phaseRepo = PhaseRepository(db);
    await _loadPhases();
  }
  // end method: _initializeRepository

  // start method: _loadPhases
  Future<void> _loadPhases() async {
    setState(() => _isLoading = true);
    final phases = await _phaseRepo.getAllPhases();
    setState(() {
      _phases = phases;
      _isLoading = false;
    });
  }
  // end method: _loadPhases

  // start method: _showEditDialog
  Future<void> _showEditDialog(Phase? phase) async {
    final isNew = phase == null;
    final nameController = TextEditingController(text: phase?.name ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Add New Phase' : 'Edit Phase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Phase Name',
                  hintText: 'e.g., Original Scope, Phase 2, Extras',
                ),
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
                      title: const Text('Delete Phase'),
                      content: Text('Are you sure you want to delete "${phase.name}"?'),
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
                    await _phaseRepo.deletePhase(phase.id!);
                    await _loadPhases();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ElevatedButton(
              child: Text(isNew ? 'Add' : 'Save'),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  if (isNew) {
                    await _phaseRepo.insertPhase(Phase(name: nameController.text.trim()));
                  } else {
                    await _phaseRepo.updatePhase(phase.copyWith(name: nameController.text.trim()));
                  }
                  await _loadPhases();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
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
        title: const Text('Manage Phases'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Phase Form Card
            AddPhaseForm(onPhaseAdded: _loadPhases),
            const SizedBox(height: 16),
            // Phase List Card
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                margin: EdgeInsets.zero,
                child: _phases.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No phases yet. Add one above.'),
                  ),
                )
                    : ListView.builder(
                  itemCount: _phases.length,
                  itemBuilder: (context, index) {
                    final phase = _phases[index];
                    return ListTile(
                      leading: const Icon(Icons.label),
                      title: Text(phase.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(phase),
                      ),
                      onTap: () => _showEditDialog(phase),
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
// end class: _ManagePhasesPageState

// start class: AddPhaseForm
class AddPhaseForm extends StatefulWidget {
  final VoidCallback onPhaseAdded;

  const AddPhaseForm({
    Key? key,
    required this.onPhaseAdded,
  }) : super(key: key);

  @override
  State<AddPhaseForm> createState() => _AddPhaseFormState();
}
// end class: AddPhaseForm

// start class: _AddPhaseFormState
class _AddPhaseFormState extends State<AddPhaseForm> {
  late PhaseRepository _phaseRepo;
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

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
    _phaseRepo = PhaseRepository(db);
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
        const SnackBar(content: Text('Phase name is required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _phaseRepo.insertPhase(Phase(name: name));
      _nameController.clear();
      widget.onPhaseAdded();
    } catch (e) {
      debugPrint('Error adding phase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding phase: $e')),
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
                  'Add New Phase',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About Phases'),
                        content: const Text(
                            'Phases help you track project scope changes.\n\n'
                                'Examples:\n'
                                '• Original Scope - Initial contracted work\n'
                                '• Phase 2 - Planned additions\n'
                                '• Extras - Unplanned add-ons\n'
                                '• Change Orders - Client-requested changes\n\n'
                                'Tag time entries and materials with phases to compare costs and see how the project evolved.'
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
                  tooltip: 'What are phases?',
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
                      labelText: 'Phase Name',
                      hintText: 'e.g., Original Scope, Phase 2, Extras',
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
                      : const Text('Add Phase'),
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
// end class: _AddPhaseFormState