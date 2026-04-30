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

  // Dropdown data
  List<DropdownItem> _clients = [];
  List<DropdownItem> _projects = [];
  List<DropdownItem> _employees = [];
  List<DropdownItem> _costCodes = [];

  // Selected filter values
  int? _selectedClientId;
  int? _selectedProjectId;
  int? _selectedEmployeeId;
  int? _selectedCostCodeId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;

  // Column toggles per subject
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
  final Map<String, bool> _projectDetailIncludes = {
    'Date': true,
    'Type (Labour/Material)': true,
    'Employee': true,
    'Supplier': false,
    'Description': true,
    'Hours': true,
    'Unit Cost': false,
    'Total Cost': true,
    'Cost Code': false,
    'Billed Status': false,
  };

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 90));
    _loadDropdownData();
  }

  Future<void> _loadDropdownData({int? clientId}) async {
    setState(() => _isLoading = true);
    final clients = await _repo.getClients();
    final projects = await _repo.getProjects(clientId: clientId);
    final employees = await _repo.getEmployees();
    final costCodes = await _repo.getCostCodes();
    setState(() {
      _clients = clients;
      _projects = projects;
      _employees = employees;
      _costCodes = costCodes;
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
        _selectedClientId = null;
        _selectedProjectId = null;
        _selectedEmployeeId = null;
        _selectedCostCodeId = null;
      });
    }
  }

  Map<String, bool> get _currentIncludes {
    switch (_subject) {
      case ReportSubject.projects:
        return _projectIncludes;
      case ReportSubject.personnel:
        return _personnelIncludes;
      case ReportSubject.projectDetail:
        return _projectDetailIncludes;
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
                    const Text('Choose a primary subject:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildPrimarySubjectGrid(),
                    const SizedBox(height: 24),
                    _buildColumnToggles(),
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
            Navigator.of(context).pop(
              CustomReportSettings(
                subject: _subject,
                includes: Map.from(_currentIncludes),
                clientId: _selectedClientId,
                projectId: _selectedProjectId,
                employeeId: _selectedEmployeeId,
                costCodeId: _selectedCostCodeId,
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
    const labels = {
      ReportSubject.projects: 'Projects',
      ReportSubject.personnel: 'Personnel',
      ReportSubject.projectDetail: 'Project Detail',
    };
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
            Text(labels[subject]!),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildColumnToggles() {
    final includes = _currentIncludes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Include these columns:',
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
          itemCount: includes.length,
          itemBuilder: (context, index) {
            final key = includes.keys.elementAt(index);
            return CheckboxListTile(
              title: Text(key),
              value: includes[key],
              onChanged: (bool? value) =>
                  setState(() => includes[key] = value!),
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
        const Text('Filter by:', style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        if (_subject == ReportSubject.projects) ...[
          Row(children: [
            Expanded(child: _buildClientDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildProjectDropdown()),
          ]),
        ] else if (_subject == ReportSubject.personnel) ...[
          _buildEmployeeDropdown(),
        ] else if (_subject == ReportSubject.projectDetail) ...[
          Row(children: [
            Expanded(child: _buildClientDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildProjectDropdown()),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildEmployeeDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildCostCodeDropdown()),
          ]),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildDateFilter(isStart: true)),
          const SizedBox(width: 16),
          Expanded(child: _buildDateFilter(isStart: false)),
        ]),
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
        ...{ for (final c in _clients) c.id: c }.values.map(
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
        ...{ for (final p in _projects) p.id: p }.values.map(
            (p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name))),
      ],
      onChanged: (int? v) => setState(() => _selectedProjectId = v),
    );
  }

  Widget _buildEmployeeDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
          labelText: 'Employee', border: OutlineInputBorder()),
      value: _selectedEmployeeId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Employees')),
        ...{ for (final e in _employees) e.id: e }.values.map(
            (e) => DropdownMenuItem<int>(value: e.id, child: Text(e.name))),
      ],
      onChanged: (int? v) => setState(() => _selectedEmployeeId = v),
    );
  }

  Widget _buildCostCodeDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
          labelText: 'Cost Code', border: OutlineInputBorder()),
      value: _selectedCostCodeId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Cost Codes')),
        ...{ for (final c in _costCodes) c.id: c }.values.map(
            (c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))),
      ],
      onChanged: (int? v) => setState(() => _selectedCostCodeId = v),
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
