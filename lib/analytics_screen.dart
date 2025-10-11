// lib/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // We need this for formatting dates

// Helper enums
enum AnalyticsView { none, projectSummary, personnelSummary, customReport }
enum ReportType { activeProjects, completedProjects }

// ENUM for our "smart" report builder - FINALIZED
enum ReportSubject { projects, personnel, expenses }

// Model to hold the settings from the dialog
class CustomReportSettings {
  final ReportSubject subject;
  final Map<String, bool> includes;
  final String? projectId;
  final String? clientId;
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
  String? _selectedProject;

  CustomReportSettings? _customReportSettings;

  void _showSelectDataDialog() {
    showDialog<CustomReportSettings>(
      context: context,
      builder: (BuildContext context) {
        return const _SelectDataDialog();
      },
    ).then((settings) {
      if (settings != null) {
        print(
            "Final settings: Subject=${settings.subject}, Includes=${settings.includes}, Start=${settings.startDate}, End=${settings.endDate}");
        setState(() {
          _customReportSettings = settings;
          _currentView = AnalyticsView.customReport;
        });
      }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentView != AnalyticsView.customReport)
                      _buildSummaryCard(),
                    if (_currentView != AnalyticsView.customReport)
                      const SizedBox(height: 24),
                    _buildDynamicContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedHeader() {
    /* Unchanged */
    return Column(
      children: [
        _buildReportSelector(),
        const SizedBox(height: 16),
        _buildHorizontalActionButtons(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    /* Unchanged */
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Project Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildUltraDenseSummaryDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSelector() {
    /* Unchanged */
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<ReportType>(
            decoration: const InputDecoration(
                labelText: 'Report Type',
                border: OutlineInputBorder(),
                filled: true),
            value: _selectedReportType,
            items: const [
              DropdownMenuItem(
                  value: ReportType.activeProjects,
                  child: Text('Active Projects')),
              DropdownMenuItem(
                  value: ReportType.completedProjects,
                  child: Text('Completed Projects')),
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
              labelText: _selectedReportType == ReportType.activeProjects
                  ? 'Select Active Project'
                  : 'Select Completed Project',
              border: const OutlineInputBorder(),
              filled: true,
            ),
            items: _getSecondaryDropdownItems(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _selectedProject = value;
              });
            },
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getSecondaryDropdownItems() {
    /* Unchanged */
    if (_selectedReportType == ReportType.activeProjects) {
      return const [
        DropdownMenuItem(
            value: 'active_proj_1', child: Text('Mobile App Development')),
        DropdownMenuItem(
            value: 'active_proj_2', child: Text('Website Redesign')),
      ];
    } else {
      return const [
        DropdownMenuItem(
            value: 'completed_proj_1', child: Text('Old System Maintenance')),
        DropdownMenuItem(
            value: 'completed_proj_2', child: Text('Marketing Campaign Site')),
      ];
    }
  }

  Widget _buildHorizontalActionButtons() {
    /* Unchanged */
    return Row(
      children: [
        Expanded(
            child: ElevatedButton.icon(
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Project Summary'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () =>
                    setState(() => _currentView = AnalyticsView.projectSummary))),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton.icon(
                icon: const Icon(Icons.people_outline),
                label: const Text('Personnel Summary'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreen,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => setState(
                        () => _currentView = AnalyticsView.personnelSummary))),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton.icon(
                icon: const Icon(Icons.checklist_rtl_outlined),
                label: const Text('Select Data'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _showSelectDataDialog)),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('Export Details'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {/* Placeholder */})),
      ],
    );
  }

  Widget _buildUltraDenseSummaryDetails() {
    /* Omitted for brevity */
    return const Column(children: [
      IntrinsicHeight(
          child: Row(children: [
            _SummaryItem(label: 'Project:', value: 'Mobile App Development'),
            VerticalDivider(width: 24.0, thickness: 1),
            _SummaryItem(label: 'Billed Rate:', value: '\$100.00 / hour'),
            VerticalDivider(width: 24.0, thickness: 1),
            _SummaryItem(label: 'Pricing Model:', value: 'Hourly'),
            VerticalDivider(width: 24.0, thickness: 1),
            _SummaryItem(label: 'Total Hours:', value: '125.50')
          ])),
      Divider(height: 24.0),
      IntrinsicHeight(
          child: Row(children: [
            _SummaryItem(label: 'Total Labor Cost:', value: '\$6,275.00'),
            VerticalDivider(width: 24.0, thickness: 1),
            _SummaryItem(label: 'Total Expenses:', value: '\$1,500.75'),
            VerticalDivider(width: 24.0, thickness: 1),
            _SummaryItem(label: 'Total Billed Value:', value: '\$12,550.00'),
            VerticalDivider(width: 24.0, thickness: 1),
            _SummaryItem(label: 'Profit/Loss:', value: '\$4,774.25')
          ]))
    ]);
  }

  Widget _buildDynamicContent() {
    /* Omitted for brevity */
    switch (_currentView) {
      case AnalyticsView.projectSummary:
        return _buildProjectSummaryTable();
      case AnalyticsView.personnelSummary:
        return _buildPersonnelSummaryTable();
      case AnalyticsView.customReport:
        if (_customReportSettings == null) {
          return const Center(child: Text("No report settings selected."));
        }
        return Card(
            elevation: 2,
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                "Custom Report: ${_customReportSettings!.subject.name[0].toUpperCase()}${_customReportSettings!.subject.name.substring(1)}",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                        () => _currentView = AnalyticsView.none))
                          ]),
                      const SizedBox(height: 12),
                      DataTable(
                          columns: _buildCustomReportHeaders(),
                          rows: _buildCustomReportRows())
                    ])));
      case AnalyticsView.none:
        return const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child:
                Text("Select a report to view using the buttons above.")));
    }
  }

  List<DataColumn> _buildCustomReportHeaders() {
    /* Omitted for brevity */
    if (_customReportSettings == null) return [];
    List<DataColumn> columns = [];
    final settings = _customReportSettings!;
    if (settings.subject == ReportSubject.projects) {
      columns.add(const DataColumn(label: Text('Project')));
      if (settings.includes['Client Details'] ?? false) {
        columns.add(const DataColumn(label: Text('Client')));
      }
      if (settings.includes['Time Entry Totals'] ?? false) {
        columns.add(const DataColumn(label: Text('Total Hours'), numeric: true));
      }
      if (settings.includes['Expense Totals'] ?? false) {
        columns.add(const DataColumn(label: Text('Expenses'), numeric: true));
      }
    }
    // Logic for Personnel and Expenses will go here later
    return columns;
  }

  List<DataRow> _buildCustomReportRows() {
    /* Omitted for brevity */
    if (_customReportSettings == null) return [];
    if (_customReportSettings!.subject == ReportSubject.projects) {
      return List.generate(5, (index) {
        List<DataCell> cells = [];
        cells.add(DataCell(Text('Project Alpha ${index + 1}')));
        if (_customReportSettings!.includes['Client Details'] ?? false) {
          cells.add(DataCell(Text('Client #${index + 1}')));
        }
        if (_customReportSettings!.includes['Time Entry Totals'] ?? false) {
          cells.add(DataCell(Text('${85 + index * 5}.0')));
        }
        if (_customReportSettings!.includes['Expense Totals'] ?? false) {
          cells.add(DataCell(Text('\$${400 + index * 20}')));
        }
        return DataRow(cells: cells);
      });
    }
    // Logic for Personnel and Expenses will go here later
    return [];
  }

  Widget _buildProjectSummaryTable() {
    /* Omitted for brevity */
    final List<DataRow> rows = List.generate(
        25,
            (i) => const DataRow(cells: [
          DataCell(Text('Mobile App Dev')),
          DataCell(Text('BigCorp Inc.')),
          DataCell(Text('Hourly')),
          DataCell(Text('125.5')),
          DataCell(Text('\$6,275')),
          DataCell(Text('\$12,550')),
          DataCell(Text('\$6,275'))
        ]));
    return Card(
        elevation: 2,
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('All Projects',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(
                                    () => _currentView = AnalyticsView.none))
                      ]),
                  const SizedBox(height: 12),
                  DataTable(columns: const [
                    DataColumn(label: Text('Project')),
                    DataColumn(label: Text('Client')),
                    DataColumn(label: Text('Pricing')),
                    DataColumn(label: Text('Total Hours'), numeric: true),
                    DataColumn(label: Text('Total Cost'), numeric: true),
                    DataColumn(label: Text('Billed Value'), numeric: true),
                    DataColumn(label: Text('Profit/Loss'), numeric: true)
                  ], rows: rows)
                ])));
  }

  Widget _buildPersonnelSummaryTable() {
    /* Omitted for brevity */
    final List<DataRow> rows = List.generate(
        25,
            (i) => const DataRow(cells: [
          DataCell(Text('John Doe')),
          DataCell(Text('Developer')),
          DataCell(Text('Active')),
          DataCell(Text('150.0')),
          DataCell(Text('\$15,000'))
        ]));
    return Card(
        elevation: 2,
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Personnel Summary',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(
                                    () => _currentView = AnalyticsView.none))
                      ]),
                  const SizedBox(height: 12),
                  DataTable(columns: const [
                    DataColumn(label: Text('Employee')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Total Hours'), numeric: true),
                    DataColumn(label: Text('Total Billed'), numeric: true)
                  ], rows: rows)
                ])));
  }
}

class _SummaryItem extends StatelessWidget {
  /* Omitted for brevity */
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
            ]));
  }
}

// ####################################################################
// ## DIALOG WIDGET IS REBUILT WITH FINAL LAYOUT AND CHOICES ##
// ####################################################################
class _SelectDataDialog extends StatefulWidget {
  const _SelectDataDialog();

  @override
  State<_SelectDataDialog> createState() => _SelectDataDialogState();
}

class _SelectDataDialogState extends State<_SelectDataDialog> {
  // --- STATE VARIABLES ---
  ReportSubject _subject = ReportSubject.projects;

  final Map<String, bool> _projectIncludes = {
    'Client Details': true,
    'Time Entry Totals': true,
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

  String? _selectedProjectId;
  String? _selectedClientId;
  DateTime? _startDate;
  DateTime? _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Custom Report'),
      // Set a specific width for the dialog
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5, // 50% of screen width
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Primary Subject ---
              const Text("Choose a primary subject:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              _buildPrimarySubjectGrid(), // Using new Grid layout
              const SizedBox(height: 24),

              // --- 2. Secondary Includes ---
              _buildSecondaryOptions(), // Now handles all subjects
              const SizedBox(height: 24),

              // --- 3. Filter Section ---
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
            // Get the correct "includes" map based on the subject
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
                projectId: _selectedProjectId,
                clientId: _selectedClientId,
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

  // --- HELPER WIDGETS ---

  Widget _buildPrimarySubjectGrid() {
    final subjects = ReportSubject.values;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 5 / 1, // Adjust aspect ratio for wider items
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: subjects.length,
      shrinkWrap: true, // Important for GridView inside SingleChildScrollView
      physics:
      const NeverScrollableScrollPhysics(), // Disable scrolling on the grid itself
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return RadioListTile<ReportSubject>(
          title: Text(
              subject.name[0].toUpperCase() + subject.name.substring(1)),
          value: subject,
          groupValue: _subject,
          onChanged: (ReportSubject? value) {
            if (value == null) return;
            setState(() {
              _subject = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          tileColor: Colors.grey.shade100,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      },
    );
  }

  Widget _buildSecondaryOptions() {
    Map<String, bool>? currentIncludes;
    String title = "";

    switch (_subject) {
      case ReportSubject.projects:
        currentIncludes = _projectIncludes;
        title = "Include with Projects:";
        break;
      case ReportSubject.personnel:
        currentIncludes = _personnelIncludes;
        title = "Include with Personnel:";
        break;
      case ReportSubject.expenses:
        currentIncludes = _expenseIncludes;
        title = "Include with Expenses:";
        break;
    }

    final keys = currentIncludes.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 5 / 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 0,
          ),
          itemCount: keys.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final key = keys[index];
            return CheckboxListTile(
              title: Text(key),
              // BUG FIX: Added '!' to assert that currentIncludes is not null here.
              value: currentIncludes![key],
              onChanged: (bool? value) {
                setState(() {
                  // BUG FIX: Added '!' here as well.
                  currentIncludes![key] = value!;
                });
              },
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
    /* Unchanged */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Filter Results By:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildProjectFilterDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildClientFilterDropdown()),
          ],
        ),
        const SizedBox(height: 16),
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

  Widget _buildProjectFilterDropdown() {
    /* Unchanged */
    return DropdownButtonFormField<String>(
      value: _selectedProjectId,
      decoration: const InputDecoration(
          labelText: 'Project', border: OutlineInputBorder(), filled: true),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Projects')),
        DropdownMenuItem(
            value: 'proj_1', child: Text('Mobile App Development')),
        DropdownMenuItem(value: 'proj_2', child: Text('Website Redesign')),
      ],
      onChanged: (String? value) {
        setState(() {
          _selectedProjectId = value;
        });
      },
    );
  }

  Widget _buildClientFilterDropdown() {
    /* Unchanged */
    return DropdownButtonFormField<String>(
      value: _selectedClientId,
      decoration: const InputDecoration(
          labelText: 'Client', border: OutlineInputBorder(), filled: true),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Clients')),
        DropdownMenuItem(value: 'client_1', child: Text('BigCorp Inc.')),
        DropdownMenuItem(value: 'client_2', child: Text('Startup LLC')),
      ],
      onChanged: (String? value) {
        setState(() {
          _selectedClientId = value;
        });
      },
    );
  }

  Widget _buildDatePicker({required bool isStart}) {
    /* Unchanged */
    DateTime? date = isStart ? _startDate : _endDate;
    String title = isStart ? 'Start Date' : 'End Date';
    String buttonText =
    date == null ? 'Select Date' : DateFormat('MM/dd/yyyy').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(58), // Match dropdown height
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
          ),
          onPressed: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (pickedDate != null) {
              setState(() {
                if (isStart) {
                  _startDate = pickedDate;
                } else {
                  _endDate = pickedDate;
                }
              });
            }
          },
        ),
      ],
    );
  }
}
