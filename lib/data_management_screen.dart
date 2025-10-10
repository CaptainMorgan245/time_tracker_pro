// lib/data_management_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; // Still using this for getDirectoryPath()
import 'package:time_tracker_pro/database_helper.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;

  // == FINAL, CORRECTED EXPORT FUNCTION USING A NEW STRATEGY ==
  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // 1. GET DATA FROM DATABASE (This is working perfectly)
      final dbHelper = DatabaseHelperV2.instance;
      final jsonString = await dbHelper.exportDatabaseToJson();

      // Simple check to ensure we have data
      if (jsonString.isEmpty || jsonString.length < 100) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database is empty. Nothing to export.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      // 2. NEW STRATEGY: ASK USER TO SELECT A DIRECTORY
      // The FilePicker.platform.saveFile() method is buggy and causes the crash.
      // We will use getDirectoryPath() instead, which is more stable.
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Please select a folder to save your backup:',
      );

      // If the user cancels the directory picker
      if (selectedDirectory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled: No folder was selected.')),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      // 3. MANUALLY CREATE THE FILE PATH AND WRITE THE FILE
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'time_tracker_pro_backup_$timestamp.json';
      // Combine the selected directory path and the new file name
      final filePath = '$selectedDirectory/$fileName';

      final file = File(filePath);
      // Use writeAsString, as the crash was not with this, but with the plugin's native code.
      await file.writeAsString(jsonString, encoding: utf8);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup saved successfully in your selected folder!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
  // == END FINAL, CORRECTED EXPORT FUNCTION ==


  Future<void> _importData() async {
    // This function remains the same and should work correctly.
    if (_isImporting) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import cancelled.')));
      return;
    }

    final String path = result.files.single.path!;
    final file = File(path);
    final jsonString = await file.readAsString();

    if (jsonString.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Import Failed: The selected backup file is empty.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Overwrite All Data?'),
          content: const Text(
              'Restoring from this backup will completely ERASE and REPLACE all current data in the app. This action cannot be undone.\n\nAre you absolutely sure you want to continue?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            FilledButton.tonal(
              child: const Text('Yes, Overwrite My Data', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import cancelled.')));
      return;
    }

    setState(() => _isImporting = true);

    try {
      final dbHelper = DatabaseHelperV2.instance;
      await dbHelper.importDatabaseFromJson(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Import successful! All data has been restored.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Import Failed: $e. Your original data has been preserved.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _clearAllData() async {
    // This function remains the same
    if (_isClearing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you absolutely sure you want to delete all data? This action cannot be undone and the app will restart with a clean slate.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('DELETE ALL DATA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operation cancelled.')));
      return;
    }

    setState(() => _isClearing = true);

    try {
      final dbHelper = DatabaseHelperV2.instance;
      await dbHelper.deleteAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been cleared successfully. The app is now reset.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error clearing data: $e')));
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This part is unchanged.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSectionHeader(context, 'Database Backup & Restore'),
            const SizedBox(height: 8),
            _buildInfoCard('Use the options below to save a backup (Export) or restore from a backup file (Import).'),
            const SizedBox(height: 24),
            _buildActionButton(
              context: context,
              icon: Icons.file_upload_outlined,
              label: _isExporting ? 'Saving...' : 'Export Full Backup',
              onPressed: _isExporting ? () {} : _exportData,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              context: context,
              icon: Icons.file_download_outlined,
              label: _isImporting ? 'Importing...' : 'Import From Backup',
              onPressed: _isImporting ? () {} : _importData,
            ),
            const Divider(height: 48),
            _buildSectionHeader(context, 'Danger Zone'),
            const SizedBox(height: 8),
            _buildInfoCard('These actions are destructive and cannot be undone. Use with extreme caution.'),
            const SizedBox(height: 24),
            _buildActionButton(
              context: context,
              icon: Icons.delete_forever_outlined,
              label: _isClearing ? 'Clearing...' : 'Clear All Data',
              onPressed: _isClearing ? () {} : _clearAllData,
              color: Colors.red.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Card(
      elevation: 0,
      color: Colors.blueGrey.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(text, style: const TextStyle(height: 1.5)),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;
    final onButtonColor = theme.colorScheme.onPrimary;
    bool isLoading = (label.contains('Saving...')) || (label.contains('Importing...')) || (label.contains('Clearing...'));

    return ElevatedButton.icon(
      icon: isLoading
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: onButtonColor))
          : Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: onButtonColor,
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: theme.textTheme.titleMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
