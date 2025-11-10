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
  // Filter and sort state
  String _recordFilter = 'all'; // 'all', 'time', 'expense'
  String _sortBy = 'date_desc'; // 'date_desc', 'date_asc', 'id_desc'

  // **** NEW METHOD TO SHOW THE SCHEMA ****
  // This contains all the logic, without touching the database_helper.dart file.
  Future<void> _showDatabaseSchema() async {
    // Show a loading indicator so the user knows something is happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Get a direct reference to the database instance from our helper.
      final db = await DatabaseHelperV2.instance.database;

      // 2. Query the special 'sqlite_master' table to get schema info.
      // This is a standard SQLite command.
      final List<Map<String, dynamic>> tables = await db.query(
        'sqlite_master',
        columns: ['name', 'sql'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      // 3. Build a readable string from the query results.
      String schema;
      if (tables.isEmpty) {
        schema = 'No user-created tables found in the database.';
      } else {
        final schemaBuffer = StringBuffer();
        schemaBuffer.writeln('DATABASE SCHEMA:\n');

        for (final table in tables) {
          final tableName = table['name'];
          // This makes the output more readable by adding newlines
          final creationSql = table['sql']?.toString().replaceAll(', ', ',\n  ') ?? 'Could not retrieve schema.';

          schemaBuffer.writeln('--- TABLE: $tableName ---');
          schemaBuffer.writeln('$creationSql;\n');
        }
        schema = schemaBuffer.toString();
      }

      if (!mounted) return;
      Navigator.pop(context); // Close the loading indicator

      // 4. Show the final schema string in a scrollable dialog.
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database Schema'),
          // **** THIS IS THE ONLY CHANGE ****
          // Using SelectableText allows you to long-press and copy the content.
          content: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText( // CHANGED FROM Text to SelectableText
                schema,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator on error too
      // If something goes wrong (e.g., table doesn't exist), show an error.
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error Fetching Schema'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  List<AllRecordViewModel> _filterAndSortRecords(List<AllRecordViewModel> records) {
    // Apply filter
    List<AllRecordViewModel> filtered = records;
    if (_recordFilter == 'time') {
      filtered = records.where((r) => r.type == RecordType.time).toList();
    } else if (_recordFilter == 'expense') {
      filtered = records.where((r) => r.type == RecordType.expense).toList();
    }

    // Apply sort
    switch (_sortBy) {
      case 'date_desc':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'id_desc':
        filtered.sort((a, b) => b.id.compareTo(a.id));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer (V2)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'View Database Schema',
            onPressed: _showDatabaseSchema,
          ),
        ],
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
                return Column(children: [
                  _buildV2Indicator(dbVersion),
                  _buildFilterControls(),
                  const Expanded(child: Center(child: Text('No records found in the database.')))
                ]);
              }

              final allRecords = snapshot.data!;
              final filteredRecords = _filterAndSortRecords(allRecords);

              return Column(
                children: [
                  _buildV2Indicator(dbVersion, isLoading: isLoading),
                  _buildFilterControls(),
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? const Center(child: Text('No records match the current filter.'))
                        : ListView.builder(
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) => _buildRecordCard(filteredRecords[index]),
                    ),
                  ),
                ],
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

  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey.shade200,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _recordFilter,
              decoration: const InputDecoration(
                labelText: 'Show',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Records')),
                DropdownMenuItem(value: 'time', child: Text('Time Entries Only')),
                DropdownMenuItem(value: 'expense', child: Text('Expenses Only')),
              ],
              onChanged: (value) {
                setState(() {
                  _recordFilter = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: const InputDecoration(
                labelText: 'Sort By',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'date_desc', child: Text('Date (Newest First)')),
                DropdownMenuItem(value: 'date_asc', child: Text('Date (Oldest First)')),
                DropdownMenuItem(value: 'id_desc', child: Text('ID (Newest First)')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
          ),
        ],
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