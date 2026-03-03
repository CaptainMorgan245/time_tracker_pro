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

  // **** NEW: SQL Query Runner ****
  final TextEditingController _sqlController = TextEditingController();
  List<Map<String, dynamic>>? _queryResults;
  String? _queryError;

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  // **** NEW: Execute Custom SQL Query ****
  Future<void> _executeQuery() async {
    final query = _sqlController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _queryError = 'Please enter a SQL query';
        _queryResults = null;
      });
      return;
    }

    // Safety check: Only allow SELECT queries
    if (!query.toUpperCase().startsWith('SELECT')) {
      setState(() {
        _queryError = 'Only SELECT queries are allowed for safety';
        _queryResults = null;
      });
      return;
    }

    try {
      final db = await DatabaseHelperV2.instance.database;
      final results = await db.rawQuery(query);

      setState(() {
        _queryResults = results;
        _queryError = null;
      });
    } catch (e) {
      setState(() {
        _queryError = e.toString();
        _queryResults = null;
      });
    }
  }

  // **** NEW: Show SQL Query Dialog ****
  void _showQueryRunner() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SQL Query Runner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sqlController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'SELECT * FROM time_entries ORDER BY id DESC LIMIT 10',
                  labelText: 'SQL Query (SELECT only)',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _executeQuery,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Execute'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _sqlController.clear();
                        _queryResults = null;
                        _queryError = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_queryError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade100,
                  child: SelectableText(
                    'Error: $_queryError',
                    style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_queryResults != null) ...[
                Text('Results: ${_queryResults!.length} rows', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: _queryResults!.isEmpty
                      ? const Center(child: Text('No results'))
                      : Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
                          border: TableBorder.all(color: Colors.grey),
                          columns: _queryResults!.first.keys.map((key) {
                            return DataColumn(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)));
                          }).toList(),
                          rows: _queryResults!.map((row) {
                            return DataRow(
                              cells: row.values.map((value) {
                                return DataCell(SelectableText(value?.toString() ?? 'NULL', style: const TextStyle(fontSize: 12)));
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (_queryError == null)
                const Expanded(child: Center(child: Text('Enter a SELECT query and press Execute'))),
            ],
          ),
        ),
      ),
    );
  }

  // **** SHOW DATABASE SCHEMA ****
  Future<void> _showDatabaseSchema() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = await DatabaseHelperV2.instance.database;
      final List<Map<String, dynamic>> tables = await db.query(
        'sqlite_master',
        columns: ['name', 'sql'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      String schema;
      if (tables.isEmpty) {
        schema = 'No user-created tables found in the database.';
      } else {
        final schemaBuffer = StringBuffer();
        schemaBuffer.writeln('DATABASE SCHEMA:\n');

        for (final table in tables) {
          final tableName = table['name'];
          final creationSql = table['sql']?.toString().replaceAll(', ', ',\n  ') ?? 'Could not retrieve schema.';

          schemaBuffer.writeln('--- TABLE: $tableName ---');
          schemaBuffer.writeln('$creationSql;\n');
        }
        schema = schemaBuffer.toString();
      }

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database Schema'),
          content: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
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
      Navigator.pop(context);
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
    List<AllRecordViewModel> filtered = records;
    if (_recordFilter == 'time') {
      filtered = records.where((r) => r.type == RecordType.time).toList();
    } else if (_recordFilter == 'expense') {
      filtered = records.where((r) => r.type == RecordType.expense).toList();
    }

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
            icon: const Icon(Icons.code),
            tooltip: 'Run SQL Query',
            onPressed: _showQueryRunner,
          ),
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
      projectId: 1,
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