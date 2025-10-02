// lib/database_viewer_screen.dart

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
  // A "Future" holds the result of our database call.
  late Future<List<AllRecordViewModel>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    // Start loading the records as soon as the screen is created.
    _loadRecords();
  }

  void _loadRecords() {
    setState(() {
      // Call the function from our database helper.
      _recordsFuture = DatabaseHelper.instance.getAllRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer (Test)'),
        actions: [
          // A refresh button to try again without restarting the app.
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder<List<AllRecordViewModel>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          // Case 1: Still waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Case 2: An error occurred
          else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'AN ERROR OCCURRED:\n\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // Case 3: Data loaded, but it's empty
          else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No records found in the database.'));
          }
          // Case 4: Success! We have data.
          else {
            final records = snapshot.data!;
            return ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                // Use a simple, clear card to display the data for our test.
                return _buildRecordCard(record);
              },
            );
          }
        },
      ),
    );
  }

  // Helper widget to build a card for each record.
  Widget _buildRecordCard(AllRecordViewModel record) {
    final isTimeEntry = record.type == RecordType.time;
    final icon = isTimeEntry ? Icons.timer_outlined : Icons.shopping_cart_outlined;
    final color = isTimeEntry ? Colors.blue.shade300 : Colors.green.shade300;
    final formattedDate = DateFormat.yMMMd().format(record.date);

    final formattedValue = isTimeEntry
        ? '${record.value.toStringAsFixed(2)} hours'
        : NumberFormat.simpleCurrency().format(record.value);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(
          record.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Date: $formattedDate\nCategory/Project: ${record.categoryOrProject}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          formattedValue,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        isThreeLine: true,
      ),
    );
  }
}
