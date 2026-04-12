// lib/client_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/client_repository.dart';

class ClientAddForm extends StatefulWidget {
  final VoidCallback onClientAdded;

  const ClientAddForm({
    super.key,
    required this.onClientAdded,
  });

  @override
  State<ClientAddForm> createState() => _ClientAddFormState();
}

class _ClientAddFormState extends State<ClientAddForm> {
  final ClientRepository _clientRepo = ClientRepository();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client Name is required')),
      );
      return;
    }

    final newClient = Client(
      name: name,
      contactPerson: _contactPersonController.text.isNotEmpty ? _contactPersonController.text : null,
      phoneNumber: _phoneNumberController.text.isNotEmpty ? _phoneNumberController.text : null,
    );

    setState(() => _isSubmitting = true);

    try {
      await _clientRepo.insertClient(newClient);
      _nameController.clear();
      _contactPersonController.clear();
      _phoneNumberController.clear();
      widget.onClientAdded();
    } catch (e) {
      debugPrint('Error adding client: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding client: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Client', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Client Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _contactPersonController,
                    decoration: const InputDecoration(labelText: 'Contact Person'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneNumberController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting ? const CircularProgressIndicator() : const Text('Add Client'),
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