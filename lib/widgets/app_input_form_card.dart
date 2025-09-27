// lib/widgets/app_input_form_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable widget for displaying a standardized form input field
/// wrapped in a Card, along with a button for submission (e.g., 'Add').
///
/// This component enforces the look and structure taken from the ExpensesScreen.
// start class: AppInputFormCard
class AppInputFormCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType keyboardType;

  // start method: constructor
  const AppInputFormCard({
    super.key,
    required this.label,
    required this.controller,
    required this.onAdd,
    this.inputFormatters,
    this.keyboardType = TextInputType.text,
  });
  // end method: constructor

  // start method: build
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              inputFormatters: inputFormatters,
              keyboardType: keyboardType,
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onAdd,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
// end method: build
}
// end class: AppInputFormCard
