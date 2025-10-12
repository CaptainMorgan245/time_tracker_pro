// lib/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/custom_report_view.dart';
import 'package:time_tracker_pro/project_summary_view.dart';
import 'package:time_tracker_pro/dropdown_repository.dart'; // <-- NEW: Import for filter data

// These enums are clean and back to what they should be.
enum AnalyticsView { none, projectSummary, personnelSummary, customReport }
enum ReportType { activeProjects, completedProjects }
enum ReportSubject { projects, personnel, expenses }

class CustomReportSettings {
  final ReportSubject subject;
  final Map<String, bool> includes;
  final int? projectId; // Changed to int
  final int? clientId;  // Changed to int
  final DateTime? startDate;
  final DateTime? endDate;

  CustomReportSettings({
    required this.subject,
    required this.includes,
    this.projectId,
    this.clientId,
    this.startDate,
    this.endDate,
  });
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsView _currentView = AnalyticsView.none;
  ReportType _selectedReportType = ReportType.activeProjects;
  String? _selectedProject; // This is for the top-level filter, can be removed later

  CustomReportSettings? _customReportSettings;

  void _showSelectDataDialog() {
    showDialog<CustomReportSettings>(
      context: context,
      builder: (BuildContext context) {
        return const _SelectDataDialog();
      },
    ).then((settings) {
      if (settings != null) {
        setState(() {
          _customReportSettings = settings;
          _currentView = AnalyticsView.customReport;
        });
      }
    });
  }

  void _showProjectSummary() {
    setState(() {
      _currentView = AnalyticsView.projectSummary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          children: [
            _buildFixedHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDynamicContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicContent() {
    switch (_currentView) {
      case AnalyticsView.projectSummary:
        return ProjectSummaryView(
          onClose: () => setState(() => _currentView = AnalyticsView.none),
        );
      case AnalyticsView.personnelSummary:
        return _buildPersonnelSummaryTable();
      case AnalyticsView.customReport:
        if (_customReportSettings == null) {
          return const Center(child: Text("No report settings selected."));
        }
        return CustomReportView(
          settings: _customReportSettings!,
          onClose: () => setState(() => _currentView = AnalyticsView.none),
        );
      case AnalyticsView.none:
      default:
        return const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child: Text("Select a report to view using the buttons above.")));
    }
  }

  Widget _buildFixedHeader() {
    return Column(
      children: [
        _buildReportSelector(),
        const SizedBox(height: 16),
        _buildHorizontalActionButtons(),
      ],
    );
  }

  Widget _buildReportSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<ReportType>(
            decoration: const InputDecoration(labelText: 'Report Type', border: OutlineInputBorder(), filled: true),
            value: _selectedReportType,
            items: const [
              DropdownMenuItem(value: ReportType.activeProjects, child: Text('Active Projects')),
              DropdownMenuItem(value: ReportType.completedProjects, child: Text('Completed Projects')),
            ],
            onChanged: (ReportType? newValue) {
              if (newValue == null) return;
              setState(() {
                _selectedReportType = newValue;
                _selectedProject = null;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: _selectedProject,
            decoration: InputDecoration(
              labelText: _selectedReportType == ReportType.activeProjects ? 'Select Active Project' : 'Select Completed Project',
              border: const OutlineInputBorder(),
              filled: true,
            ),
            items: const [],
            onChanged: (String? value) {
              if (value == null) return;
              setState(() { _selectedProject = value; });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalActionButtons() {
    return Row(
      children: [
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.table_view_outlined), label: const Text('Project Summary'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _showProjectSummary)),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.people_outline), label: const Text('Personnel Summary'), style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () => setState(() => _currentView = AnalyticsView.personnelSummary))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.checklist_rtl_outlined), label: const Text('Select Data'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _showSelectDataDialog)),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.ios_share), label: const Text('Export Details'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () {})),
      ],
    );
  }

  Widget _buildPersonnelSummaryTable() {
    return const Card(elevation: 2, child: Padding(padding: EdgeInsets.all(16.0), child: Text("This will be the standard Personnel Summary report.")));
  }
}

// Dialog Implementation
class _SelectDataDialog extends StatefulWidget {
  const _SelectDataDialog();

  @override
  State<_SelectDataDialog> createState() => _SelectDataDialogState();
}

class _SelectDataDialogState extends State<_SelectDataDialog> {
  // State for Dialog
  ReportSubject _subject = ReportSubject.projects;
  final _repo = DropdownRepository();

  // State for filters
  List<DropdownItem> _clients = [];
  List<DropdownItem> _projects = [];
  int? _selectedClientId;
  int? _selectedProjectId;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;

  // Checkbox states
  final Map<String, bool> _projectIncludes = {
    'Client Details': true,
    'Total Hours': true,
    'Billed Rate': true,
    'Expense Totals': false,
  };
  final Map<String, bool> _personnelIncludes = {'Role & Status': true, 'Projects Assigned': true, 'Total Hours Logged': false, 'Total Billed Value': false,};
  final Map<String, bool> _expenseIncludes = {'Project Name': true, 'Client Name': true, 'Date Purchased': true, 'Vendor': true,};

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData({int? clientId}) async {
    setState(() { _isLoading = true; });

    // Always fetch clients
    final clients = await _repo.getClients();

    // Fetch projects, filtered by client if one is provided
    final projects = await _repo.getProjects(clientId: clientId);

    setState(() {
      _clients = clients;
      _projects = projects;
      _isLoading = false;
    });
  }

  void _onClientChanged(int? newClientId) {
    setState(() {
      _selectedClientId = newClientId;
      // When client changes, reset the selected project
      _selectedProjectId = null;
      // Reload the projects list based on the new client
      _loadDropdownData(clientId: newClientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Custom Report'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: SingleChildScrollView(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Choose a primary subject:", style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              _buildPrimarySubjectGrid(),
              const SizedBox(height: 24),
              _buildSecondaryOptions(),
              const SizedBox(height: 24),
              _buildFilterSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Map<String, bool> includes;
            switch (_subject) {
              case ReportSubject.projects: includes = _projectIncludes; break;
              case ReportSubject.personnel: includes = _personnelIncludes; break;
              case ReportSubject.expenses: includes = _expenseIncludes; break;
            }
            Navigator.of(context).pop(
              CustomReportSettings(
                subject: _subject,
                includes: includes,
                clientId: _selectedClientId,
                projectId: _selectedProjectId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildPrimarySubjectGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5 / 1, crossAxisSpacing: 10, mainAxisSpacing: 10,),
      itemCount: ReportSubject.values.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final subject = ReportSubject.values[index];
        return RadioListTile<ReportSubject>(
          title: Text(subject.name[0].toUpperCase() + subject.name.substring(1)),
          value: subject,
          groupValue: _subject,
          onChanged: (ReportSubject? value) { if (value != null) setState(() => _subject = value); },
          contentPadding: EdgeInsets.zero,
          tileColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      },
    );
  }

  Widget _buildSecondaryOptions() {
    Map<String, bool> currentIncludes;
    switch (_subject) {
      case ReportSubject.projects: currentIncludes = _projectIncludes; break;
      case ReportSubject.personnel: currentIncludes = _personnelIncludes; break;
      case ReportSubject.expenses: currentIncludes = _expenseIncludes; break;
    }
    final keys = currentIncludes.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Include columns in report:", style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5 / 1, crossAxisSpacing: 10, mainAxisSpacing: 0,),
          itemCount: keys.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final key = keys[index];
            return CheckboxListTile(
              title: Text(key),
              value: currentIncludes[key],
              onChanged: (bool? value) => setState(() => currentIncludes[key] = value!),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Filter Results By:", style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Expanded(child: _buildClientFilterDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildProjectFilterDropdown()),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildDatePicker(isStart: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildDatePicker(isStart: false)),
          ],
        ),
      ],
    );
  }

  Widget _buildClientFilterDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedClientId,
      decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder(), filled: true),
      items: _clients.map((item) => DropdownMenuItem<int>(value: item.id, child: Text(item.name))).toList(),
      onChanged: _onClientChanged,
    );
  }

  Widget _buildProjectFilterDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedProjectId,
      decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder(), filled: true),
      items: _projects.map((item) => DropdownMenuItem<int>(value: item.id, child: Text(item.name))).toList(),
      onChanged: (int? value) => setState(() => _selectedProjectId = value),
    );
  }

  Widget _buildDatePicker({required bool isStart}) {
    DateTime? date = isStart ? _startDate : _endDate;
    String title = isStart ? 'Start Date' : 'End Date';
    String buttonText = date == null ? (isStart ? 'Start Date (Optional)' : 'End Date (Optional)') : DateFormat('MM/dd/yyyy').format(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          onPressed: () async {
            DateTime? pickedDate = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
            if (pickedDate != null) setState(() { if (isStart) _startDate = pickedDate; else _endDate = pickedDate; });
          },
        ),
      ],
    );
  }
}
