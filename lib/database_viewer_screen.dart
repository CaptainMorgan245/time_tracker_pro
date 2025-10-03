// lib/screens/database_viewer_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:intl/intl.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer (V2)'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: DatabaseHelperV2.instance.databaseNotifier,
        builder: (context, dbVersion, child) {
          debugPrint("[DatabaseViewerScreen] Rebuilding because database version is now: $dbVersion");
          return FutureBuilder<List<AllRecordViewModel>>(
            future: DatabaseHelperV2.instance.getAllRecordsV2(),
            builder: (context, snapshot) {
              bool isLoading = snapshot.connectionState == ConnectionState.waiting;

              if (snapshot.hasError) {
                return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('AN ERROR OCCURRED:\n\n${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)));
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Column(children: [_buildV2Indicator(dbVersion), const Expanded(child: Center(child: Text('No records found in the database.')))]);
              }

              final records = snapshot.data!;
              return Column(
                  children: [
                    _buildV2Indicator(dbVersion, isLoading: isLoading),
                    Expanded(child: ListView.builder(itemCount: records.length, itemBuilder: (context, index) => _buildRecordCard(records[index])))
                  ]
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTestExpense,
        label: const Text('Add Test Expense'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _addTestExpense() async {
    final randomCost = (Random().nextDouble() * 100);
    final itemName = 'Test Item ${Random().nextInt(1000)}';

    final newMaterial = JobMaterials(
      projectId: 1, // IMPORTANT: Ensure a project with ID 1 exists!
      itemName: itemName,
      cost: randomCost,
      purchaseDate: DateTime.now(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adding "$itemName"...'), duration: const Duration(seconds: 1)),
      );
    }

    await DatabaseHelperV2.instance.addMaterialV2(newMaterial);
  }

  // --- WIDGET BUILDERS ---

  Widget _buildV2Indicator(int version, {bool isLoading = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Colors.green.shade100,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
            ],
            Text(
              'Using DatabaseHelperV2 | DB Version: $version',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(AllRecordViewModel record) {
    final isTimeEntry = record.type == RecordType.time;
    final icon = isTimeEntry ? Icons.timer_outlined : Icons.shopping_cart_outlined;
    final color = isTimeEntry ? Colors.blue.shade300 : Colors.green.shade300;
    final formattedDate = DateFormat.yMMMd().format(record.date);
    final formattedValue = isTimeEntry ? '${record.value.toStringAsFixed(2)} hours' : NumberFormat.simpleCurrency().format(record.value);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(record.description, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('Date: $formattedDate\n${record.categoryOrProject}', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formattedValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                // V2 CHANGE: This is the corrected code block.
                final String tableName = record.type == RecordType.time ? 'time_entries' : 'materials';
                DatabaseHelperV2.instance.deleteRecordV2(id: record.id, fromTable: tableName);
              },
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
