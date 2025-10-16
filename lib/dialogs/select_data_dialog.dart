// lib/dialogs/select_data_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/dropdown_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';

class SelectDataDialog extends StatefulWidget {
  const SelectDataDialog({super.key});
  @override
  State<SelectDataDialog> createState() => _SelectDataDialogState();
}

class _SelectDataDialogState extends State<SelectDataDialog> {
  ReportSubject _subject = ReportSubject.projects;
  final _repo = DropdownRepository();

  // State for filters
  List<DropdownItem> _clients = [];
  List<DropdownItem> _projects = [];
  List<DropdownItem> _employees = [];
  int? _selectedClientId;
  int? _selectedProjectId;
  int? _selectedEmployeeId;
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
  final Map<String, bool> _personnelIncludes = {
    'Role & Status': true,
    'Projects Assigned': true,
    'Total Hours Logged': false,
    'Total Billed Value': false,
  };
  final Map<String, bool> _expenseIncludes = {
    'Project Name': true,
    'Client Name': true,
    'Date Purchased': true,
    'Vendor': true,
  };

  @override
  void initState() {
    super.initState();
    // Set default dates
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 90));
    _loadDropdownData();
  }

  Future<void> _loadDropdownData({int? clientId}) async {
    setState(() {
      _isLoading = true;
    });
    final clients = await _repo.getClients();
    final projects = await _repo.getProjects(clientId: clientId);
    final employees = await _repo.getEmployees();
    setState(() {
      _clients = clients;
      _projects = projects;
      _employees = employees;
      _isLoading = false;
    });
  }

  void _onClientChanged(int? newClientId) {
    setState(() {
      _selectedClientId = newClientId;
      _selectedProjectId = null;
      _loadDropdownData(clientId: newClientId);
    });
  }

  void _onSubjectChanged(ReportSubject? newSubject) {
    if (newSubject != null) {
      setState(() {
        _subject = newSubject;
        // Reset filters when subject changes
        _selectedClientId = null;
        _selectedProjectId = null;
        _selectedEmployeeId = null;
      });
    }
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
              const Text("Choose a primary subject:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Map<String, bool> includes;
            switch (_subject) {
              case ReportSubject.projects:
                includes = _projectIncludes;
                break;
              case ReportSubject.personnel:
                includes = _personnelIncludes;
                break;
              case ReportSubject.expenses:
                includes = _expenseIncludes;
                break;
            }
            Navigator.of(context).pop(
              CustomReportSettings(
                subject: _subject,
                includes: includes,
                clientId: _selectedClientId,
                projectId: _selectedProjectId,
                employeeId: _selectedEmployeeId,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ReportSubject.values.map((subject) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<ReportSubject>(
              value: subject,
              groupValue: _subject,
              onChanged: _onSubjectChanged,
            ),
            Text(subject.name[0].toUpperCase() + subject.name.substring(1)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSecondaryOptions() {
    Map<String, bool> currentIncludes;
    switch (_subject) {
      case ReportSubject.projects:
        currentIncludes = _projectIncludes;
        break;
      case ReportSubject.personnel:
        currentIncludes = _personnelIncludes;
        break;
      case ReportSubject.expenses:
        currentIncludes = _expenseIncludes;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Include these details:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 5,
            mainAxisExtent: 30,
          ),
          itemCount: currentIncludes.length,
          itemBuilder: (context, index) {
            String key = currentIncludes.keys.elementAt(index);
            return CheckboxListTile(
              title: Text(key),
              value: currentIncludes[key],
              onChanged: (bool? value) =>
                  setState(() => currentIncludes[key] = value!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
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
        const Text("Filter by:", style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),

        // Show different dropdowns based on subject
        if (_subject == ReportSubject.projects) ...[
          Row(
            children: [
              Expanded(child: _buildClientDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildProjectDropdown()),
            ],
          ),
        ] else if (_subject == ReportSubject.personnel) ...[
          _buildEmployeeDropdown(),
        ] else if (_subject == ReportSubject.expenses) ...[
          _buildProjectDropdown(),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDateFilter(isStart: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildDateFilter(isStart: false)),
          ],
        ),
      ],
    );
  }

  Widget _buildClientDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
          labelText: 'Client', border: OutlineInputBorder()),
      value: _selectedClientId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Clients')),
        ..._clients.map(
                (c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))),
      ],
      onChanged: _onClientChanged,
    );
  }

  Widget _buildProjectDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
          labelText: 'Project', border: OutlineInputBorder()),
      value: _selectedProjectId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Projects')),
        ..._projects.map(
                (p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name))),
      ],
      onChanged: (int? newValue) => setState(() => _selectedProjectId = newValue),
    );
  }

  Widget _buildEmployeeDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
          labelText: 'Employee', border: OutlineInputBorder()),
      value: _selectedEmployeeId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Employees')),
        ..._employees.map(
                (e) => DropdownMenuItem<int>(value: e.id, child: Text(e.name))),
      ],
      onChanged: (int? newValue) => setState(() => _selectedEmployeeId = newValue),
    );
  }

  Widget _buildDateFilter({required bool isStart}) {
    final date = isStart ? _startDate : _endDate;
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: isStart ? 'Start Date' : 'End Date',
        hintText: 'Select Date',
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      controller: TextEditingController(
        text: date == null ? '' : DateFormat('yyyy-MM-dd').format(date),
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2101),
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              _startDate = picked;
            } else {
              _endDate = picked;
            }
          });
        }
      },
    );
  }
}