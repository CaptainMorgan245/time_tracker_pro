import 'package:flutter/material.dart';
import 'package:time_tracker_pro/import_errors_notifier.dart';

class ImportErrorsReport extends StatelessWidget {
  final List<ImportError> errors;

  const ImportErrorsReport({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade100,
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Errors (${errors.length})',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'These entries failed to import. Review and correct the data.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Error List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: errors.length,
          itemBuilder: (context, index) {
              final error = errors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Worker: ${error.workerName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            error.timestamp.toString().split('.')[0],
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        error.entryData,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                error.errorReason,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),


        // Clear Button
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _confirmClearErrors(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear All Errors'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmClearErrors(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Import Errors?'),
        content: const Text(
          'This will remove the error list from view. '
              'Your original CSV file still exists if you need to re-import.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ImportErrorsNotifier.instance.clearErrors();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear Errors'),
          ),
        ],
      ),
    );
  }
}