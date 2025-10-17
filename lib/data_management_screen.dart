// lib/data_management_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
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

  bool get _isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _exportData() async {
    if (!_isMobilePlatform) return;
    if (_isExporting) return;

    // Ask for optional custom name
    String? customName;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Backup Name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter a custom name (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., Before_Tax_Season',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              const Text(
                'Leave blank for auto-generated name',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                customName = controller.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Export'),
            ),
          ],
        );
      },
    );

    if (customName == null && !mounted) return;

    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final dbHelper = DatabaseHelperV2.instance;
      final jsonString = await dbHelper.exportDatabaseToJson();

      if (jsonString.isEmpty || jsonString.length < 100) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Database is empty. Nothing to export.'),
              backgroundColor: Colors.orange),
        );
        setState(() => _isExporting = false);
        return;
      }

      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

      final String fileName;
      if (customName != null && customName!.isNotEmpty) {
        final dateOnly = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final sanitizedName = customName!.replaceAll(RegExp(r'[^\w\s-]'), '_');
        fileName = 'backup_${sanitizedName}_$dateOnly.json';
      } else {
        fileName = 'backup_$timestamp.json';
      }

      const exportPath = '/storage/emulated/0/Download';
      final exportDir = Directory(exportPath);

      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final filePath = '${exportDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonString, encoding: utf8);

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('✅ Backup saved to Download/$fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('❌ Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importData() async {
    if (!_isMobilePlatform) return;
    if (_isImporting) return;

    setState(() => _isImporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Import cancelled.')));
        setState(() => _isImporting = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        throw Exception("Selected file path is invalid.");
      }

      final file = File(path);
      final jsonString = await file.readAsString();

      if (jsonString.trim().isEmpty) {
        throw Exception("The selected backup file is empty.");
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
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
        ),
      );

      if (confirmed != true) {
        messenger.showSnackBar(const SnackBar(content: Text('Import cancelled.')));
        setState(() => _isImporting = false);
        return;
      }

      await DatabaseHelperV2.instance.importDatabaseFromJson(jsonString);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Import successful! All data has been restored.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
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
    if (!_isMobilePlatform) return;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operation cancelled.')));
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
            _buildInfoCard('Use the options below to save a backup (Export) or restore from a backup file (Import). Backups are saved in the Download folder.'),
            const SizedBox(height: 24),
            _buildActionButton(
              context: context,
              icon: Icons.file_upload_outlined,
              label: _isExporting ? 'Saving...' : 'Export Full Backup',
              onPressed: _isMobilePlatform && !_isExporting ? _exportData : null,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              context: context,
              icon: Icons.file_download_outlined,
              label: _isImporting ? 'Importing...' : 'Import From Backup',
              onPressed: _isMobilePlatform && !_isImporting ? _importData : null,
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
              onPressed: _isMobilePlatform && !_isClearing ? _clearAllData : null,
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
      color: Colors.blueGrey.withAlpha(26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blueGrey.withAlpha(51)),
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
    required VoidCallback? onPressed,
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