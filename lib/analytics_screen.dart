// lib/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/custom_report_view.dart';
import 'package:time_tracker_pro/dropdown_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/project_repository.dart';


// Enums remain the same
// Use distinct names for the two report types to make state management clear
enum AnalyticsView { none, singleProjectCard, projectListTable, personnelSummary, customReport }
enum ReportType { activeProjects, completedProjects }
enum ReportSubject { projects, personnel, expenses }

// CustomReportSettings class remains the same
class CustomReportSettings {
  final ReportSubject subject;
  final Map<String, bool> includes;
  final int? projectId;
  final int? clientId;
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
  // State variables
  AnalyticsView _currentView = AnalyticsView.none;
  ReportType _selectedReportType = ReportType.activeProjects;
  int? _selectedProjectId;
  final _dropdownRepo = DropdownRepository();
  final _projectRepo = ProjectRepository();
  List<DropdownItem> _projectsForDropdown = [];
  bool _isLoadingProjects = true;
  CustomReportSettings? _customReportSettings;

  // Futures for asynchronous data loading
  Future<ProjectSummaryViewModel?>? _singleProjectCardFuture;
  Future<List<ProjectSummaryViewModel>>? _projectListTableFuture;


  // All methods up to build() remain the same
  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsForDropdown = [];
      _selectedProjectId = null;
      _currentView = AnalyticsView.none;
    });
    final bool fetchActive = _selectedReportType == ReportType.activeProjects;
    final projects = await _dropdownRepo.getProjectsByStatus(active: fetchActive);
    setState(() {
      _projectsForDropdown = projects;
      _isLoadingProjects = false;

      // If there's only one project, select it automatically and show the card
      if (projects.length == 1) {
        _selectedProjectId = projects.first.id;
        _generateSingleSummaryCard(_selectedProjectId!);
      }
    });
  }

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

  // FUNCTION 2 FIX: The original, intended purpose of the blue button (show full table)
  void _showProjectListReport() {
    setState(() {
      _currentView = AnalyticsView.projectListTable;
      _projectListTableFuture = _projectRepo.getProjectListReport(
          activeOnly: _selectedReportType == ReportType.activeProjects);
    });
  }

  // FUNCTION 1 FIX: Generates the single card view (Called on dropdown change)
  void _generateSingleSummaryCard(int projectId) {
    setState(() {
      _currentView = AnalyticsView.singleProjectCard;
      _singleProjectCardFuture = _projectRepo.getProjectSummary(projectId);
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
      case AnalyticsView.singleProjectCard: // Displayed when project is selected
        return FutureBuilder<ProjectSummaryViewModel?>(
          future: _singleProjectCardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading summary: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Project details not found.'));
            }
            final summaryData = snapshot.data!;
            return _ProjectSummaryCard(summaryData: summaryData);
          },
        );

      case AnalyticsView.projectListTable: // Displayed when "Project Summary" button is clicked
        return FutureBuilder<List<ProjectSummaryViewModel>>(
          future: _projectListTableFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading report: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No projects found for this report type.'));
            }
            return _ProjectListReport(reportData: snapshot.data!);
          },
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
      // Show project card if one is selected, even if the view was reset to none.
        if (_selectedProjectId != null && _singleProjectCardFuture != null) {
          // Note: This recursive call ensures the card stays visible if the view was reset,
          // but if we were to refactor, we would handle this state directly.
          return _buildDynamicContent();
        }
        return const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child: Text("Select a project or report to view using the controls above.")));
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
              if (newValue == null || newValue == _selectedReportType) return;
              setState(() {
                _selectedReportType = newValue;
              });
              _loadProjects();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            value: _selectedProjectId,
            decoration: InputDecoration(
              labelText: _isLoadingProjects
                  ? 'Loading...'
                  : (_selectedReportType == ReportType.activeProjects ? 'Select Active Project' : 'Select Completed Project'),
              border: const OutlineInputBorder(),
              filled: true,
            ),
            items: _isLoadingProjects
                ? [ const DropdownMenuItem( enabled: false, child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3))))]
                : _projectsForDropdown.map((item) {
              return DropdownMenuItem<int>(
                value: item.id,
                child: Text(item.name),
              );
            }).toList(),
            onChanged: (int? value) {
              if (value == null) {
                // If user selects 'null' (if you had an 'All Projects' option), reset view.
                setState(() {
                  _selectedProjectId = null;
                  _currentView = AnalyticsView.none;
                });
                return;
              }
              setState(() {
                _selectedProjectId = value;
              });
              // FIX: Generate the single summary card automatically on selection
              _generateSingleSummaryCard(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalActionButtons() {
    return Row(
      children: [
        // FIX: Reverted button action to show the list report table
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.table_view_outlined), label: const Text('Project Summary'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _showProjectListReport)),
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

// ====================================================================
// NEW WIDGETS FOR REPORT TABLE
// ====================================================================

/// Displays the full table report of projects.
class _ProjectListReport extends StatelessWidget {
  final List<ProjectSummaryViewModel> reportData;
  const _ProjectListReport({required this.reportData});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Financial Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),

            SizedBox(
              width: double.infinity,
              child: DataTable(
                columnSpacing: 12,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Expanded(child: Text('Project', style: TextStyle(fontWeight: FontWeight.bold)))),
                  DataColumn(label: Expanded(child: Text('Client', style: TextStyle(fontWeight: FontWeight.bold)))),
                  DataColumn(label: Text('Pricing', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('Billed Value', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  DataColumn(label: Text('P/L', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: reportData.map((data) => DataRow(cells: [
                  DataCell(Text(data.projectName, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(data.clientName ?? 'N/A')),
                  DataCell(Text(data.pricingModel.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join(' '))),
                  DataCell(Text(data.totalHours.toStringAsFixed(1), textAlign: TextAlign.right)),
                  DataCell(Text(_currencyFormat.format(data.totalLabourCost + data.totalExpenses), textAlign: TextAlign.right)), // Total Cost = Labour Cost + Expenses
                  DataCell(Text(_currencyFormat.format(data.totalBilledValue), textAlign: TextAlign.right)),
                  DataCell(Text(_currencyFormat.format(data.profitLoss))),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// SINGLE CARD WIDGETS
// ====================================================================

/// Formats values into a consistent currency string.
final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

/// Displays the main project summary card with all its details.
class _ProjectSummaryCard extends StatelessWidget {
  final ProjectSummaryViewModel summaryData;
  const _ProjectSummaryCard({required this.summaryData});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isHourly = summaryData.pricingModel == 'hourly';

    // Helper function to format the Billed Rate text as per your spec
    String getBilledRateText() {
      if (isHourly) {
        return '${_currencyFormat.format(summaryData.billedRate)}/hr (Burden)';
      } else if (summaryData.pricingModel == 'fixed') {
        return '${_currencyFormat.format(summaryData.billedRate)} (Fixed Price)';
      } else if (summaryData.pricingModel == 'project_based') {
        return '${_currencyFormat.format(summaryData.billedRate)} (Project Based)';
      }
      return _currencyFormat.format(summaryData.billedRate);
    }

    // Helper function to determine the model label for the card
    String getPricingModelLabel() {
      if (summaryData.pricingModel == 'hourly') return 'Hourly';
      if (summaryData.pricingModel == 'fixed') return 'Fixed Price';
      if (summaryData.pricingModel == 'project_based') return 'Project Based';
      return 'Unknown';
    }

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Card Header ---
            Text(
              summaryData.projectName,
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (summaryData.clientName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Text(
                  'Client: ${summaryData.clientName}',
                  style: textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            const Divider(thickness: 1.5, height: 24),

            // --- Details Section (FIXED LAYOUT) ---
            Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Project Name
                    Text.rich(
                      TextSpan(
                        style: textTheme.bodyLarge,
                        children: <TextSpan>[
                          const TextSpan(text: 'Project: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: summaryData.projectName),
                        ],
                      ),
                    ),
                    // Line 2: Pricing Model
                    Text.rich(
                      TextSpan(
                        style: textTheme.bodyLarge,
                        children: <TextSpan>[
                          const TextSpan(text: 'Pricing Model: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: getPricingModelLabel()),
                        ],
                      ),
                    ),
                    // Line 3: Billed Rate
                    Text.rich(
                      TextSpan(
                        style: textTheme.bodyLarge,
                        children: <TextSpan>[
                          const TextSpan(text: 'Billed Rate: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: getBilledRateText()),
                        ],
                      ),
                    ),
                  ],
                )
            ),

            const Divider(height: 1),

            // Total Hours: # | Total Expenses: #
            _SummaryDetailRow(
              label: 'Total Hours Logged:',
              value: summaryData.totalHours.toStringAsFixed(2),
            ),
            _SummaryDetailRow(
              label: 'Total Expenses:',
              value: _currencyFormat.format(summaryData.totalExpenses),
            ),

            // Total Labour Cost: hours x billed rate (only visible for Hourly projects)
            if (isHourly)
              _SummaryDetailRow(
                label: 'Total Labour Cost:',
                value: _currencyFormat.format(summaryData.totalLabourCost),
              ),

            const Divider(height: 24),

            // --- Totals Section ---
            // Total Billed Value: Total labour cost + total expenses.
            _SummaryDetailRow(
              label: 'TOTAL BILLED VALUE:',
              value: _currencyFormat.format(summaryData.totalBilledValue),
              isTotal: true, // Make the total stand out
            ),

            // Profit/Loss Display
            _SummaryDetailRow(
              label: 'PROFIT/LOSS (Provisional):',
              value: _currencyFormat.format(summaryData.profitLoss),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// A helper widget to create a consistent row for label-value pairs.
class _SummaryDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryDetailRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = isTotal
        ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : textTheme.bodyLarge;
    final valueStyle = isTotal
        ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
        : textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

// The _SelectDataDialog and its state remain unchanged at the end of the file.
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

  // Checkbox states (RESTORED)
  final Map<String, bool> _projectIncludes = { 'Client Details': true, 'Total Hours': true, 'Billed Rate': true, 'Expense Totals': false, };
  final Map<String, bool> _personnelIncludes = {'Role & Status': true, 'Projects Assigned': true, 'Total Hours Logged': false, 'Total Billed Value': false,};
  final Map<String, bool> _expenseIncludes = {'Project Name': true, 'Client Name': true, 'Date Purchased': true, 'Vendor': true,};

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData({int? clientId}) async {
    setState(() { _isLoading = true; });
    final clients = await _repo.getClients();
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
      _selectedProjectId = null;
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
              // RESTORED FUNCTION CALL
              _buildPrimarySubjectGrid(),
              const SizedBox(height: 24),
              // RESTORED FUNCTION CALL
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

  // ====================================================================
  // RESTORED RADIO BUTTON/GRID LOGIC
  // ====================================================================

  Widget _buildPrimarySubjectGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: ReportSubject.values.length,
      itemBuilder: (context, index) {
        final subject = ReportSubject.values[index];
        final isSelected = _subject == subject;
        return InkWell(
          onTap: () => setState(() => _subject = subject),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
              border: Border.all(color: isSelected ? Theme.of(context).primaryColorDark : Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subject.name[0].toUpperCase() + subject.name.substring(1),
              style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Include these details:", style: TextStyle(fontWeight: FontWeight.bold)),
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
              onChanged: (bool? value) => setState(() => currentIncludes[key] = value!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            );
          },
        ),
      ],
    );
  }

  // ====================================================================
  // FILTER SECTION REMAINS THE SAME
  // ====================================================================

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Filter by:", style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        Row(
          children: [
            Expanded(child: _buildClientDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildProjectDropdown()),
          ],
        ),
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
      decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
      value: _selectedClientId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Clients')),
        ..._clients.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))),
      ],
      onChanged: _onClientChanged,
    );
  }

  Widget _buildProjectDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder()),
      value: _selectedProjectId,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Projects')),
        ..._projects.map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name))),
      ],
      onChanged: (int? newValue) => setState(() => _selectedProjectId = newValue),
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