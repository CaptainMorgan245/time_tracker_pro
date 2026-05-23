// lib/screens/client_statement_screen.dart
//
// Client Statement screen: filters → expandable per-project results → grand
// totals + disabled PDF placeholder. `// RIVERPOD:` notes mark spots where
// providers would replace ValueNotifiers / direct repo calls later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:time_tracker_pro/client_repository.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/client_statement.dart';
import 'package:time_tracker_pro/repositories/statement_repository.dart';
import 'package:time_tracker_pro/screens/statement_pdf_preview_screen.dart';
import 'package:time_tracker_pro/widgets/browser_warning_banner.dart';

final _currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
final _dateFmt = DateFormat('yyyy-MM-dd');
const _grey = TextStyle(color: Colors.grey);
const _greySmall = TextStyle(color: Colors.grey, fontSize: 12);
const _greyLabel = TextStyle(fontSize: 11, color: Colors.grey);
const _bold = TextStyle(fontWeight: FontWeight.bold);

class ClientStatementScreen extends StatefulWidget {
  const ClientStatementScreen({super.key});
  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  // RIVERPOD: replace repos + notifiers with provider reads.
  final _clientRepo = ClientRepository();
  final _invoiceRepo = InvoiceRepository();
  final _statementRepo = StatementRepository(AppDatabase.instance);
  final ValueNotifier<List<Client>> _clients = ValueNotifier([]);
  final ValueNotifier<List<Project>> _projectsForClient = ValueNotifier([]);

  Client? _selectedClient;
  final Set<int> _selectedProjectIds = {};
  DateTime? _dateFrom;
  DateTime? _dateTo;
  ClientStatement? _statement;
  bool _isGenerating = false;
  bool _isLoadingClients = true;
  bool _isExportingPdf = false;
  String? _generateError;

  @override
  void initState() {
    super.initState();
    _loadClients();
    AppDatabase.instance.databaseNotifier.addListener(_loadClients);
  }

  @override
  void dispose() {
    AppDatabase.instance.databaseNotifier.removeListener(_loadClients);
    _clients.dispose();
    _projectsForClient.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final list = await _clientRepo.getClients();
    if (!mounted) return;
    _clients.value = list.where((c) => c.isActive).toList();
    setState(() => _isLoadingClients = false);
  }

  Future<void> _loadProjects() async {
    final id = _selectedClient?.id;
    _projectsForClient.value =
        id == null ? [] : await _invoiceRepo.getProjectsForClient(id);
  }

  void _onClientChanged(Client? c) {
    setState(() {
      _selectedClient = c;
      _selectedProjectIds.clear();
      _statement = null;
      _generateError = null;
    });
    _loadProjects();
  }

  void _toggleProject(int id, bool sel) => setState(() =>
      sel ? _selectedProjectIds.add(id) : _selectedProjectIds.remove(id));

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() => isStart ? _dateFrom = picked : _dateTo = picked);
  }

  void _clearDate(bool isStart) =>
      setState(() => isStart ? _dateFrom = null : _dateTo = null);

  Future<void> _generate() async {
    final clientId = _selectedClient?.id;
    if (clientId == null) return;
    setState(() {
      _isGenerating = true;
      _generateError = null;
      _statement = null;
    });
    try {
      // RIVERPOD: ref.read(clientStatementProvider(args).future).
      final s = await _statementRepo.getClientStatement(
        clientId: clientId,
        projectIds:
            _selectedProjectIds.isEmpty ? null : _selectedProjectIds.toList(),
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted) return;
      setState(() => _statement = s);
    } catch (e) {
      if (!mounted) return;
      setState(() => _generateError = e.toString());
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportPdf() async {
    final statement = _statement;
    if (statement == null) return;

    setState(() => _isExportingPdf = true);

    try {
      final company = await AppDatabase.instance.getCompanySettings();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StatementPdfPreviewScreen(
            statement: statement,
            companySettings: company,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open preview: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Statement')),
      body: Column(children: [
        const BrowserWarningBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatementFilters(
                  isLoadingClients: _isLoadingClients,
                  clients: _clients,
                  projectsForClient: _projectsForClient,
                  selectedClient: _selectedClient,
                  selectedProjectIds: _selectedProjectIds,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  onClientChanged: _onClientChanged,
                  onProjectToggled: _toggleProject,
                  onPickDate: _pickDate,
                  onClearDate: _clearDate,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Generate Statement',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: (_selectedClient != null && !_isGenerating)
                        ? _generate
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isGenerating)
                  const Center(child: CircularProgressIndicator())
                else if (_generateError != null)
                  _errorCard(_generateError!)
                else if (_statement != null)
                  ..._buildResults(
                    _statement!,
                    onExportPdf: _exportPdf,
                    isExportingPdf: _isExportingPdf,
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

List<Widget> _buildResults(
  ClientStatement s, {
  required VoidCallback onExportPdf,
  required bool isExportingPdf,
}) {
  final range = StringBuffer('Generated ${_dateFmt.format(s.statementDate)}');
  if (s.dateFrom != null || s.dateTo != null) {
    range
      ..write('  •  ')
      ..write(s.dateFrom != null ? _dateFmt.format(s.dateFrom!) : 'Beginning')
      ..write(' → ')
      ..write(s.dateTo != null ? _dateFmt.format(s.dateTo!) : 'Today');
  }
  return [
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.client.name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(range.toString(), style: _greySmall),
        ]),
      ),
    ),
    const SizedBox(height: 12),
    if (s.projectStatements.isEmpty)
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No activity for the selected filters.'),
        ),
      )
    else
      ...s.projectStatements.map((ps) => _ProjectStatementCard(ps: ps)),
    const SizedBox(height: 12),
    _GrandTotalsCard(statement: s),
    const SizedBox(height: 12),
    SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        icon: isExportingPdf
            ? Builder(
                builder: (ctx) => SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: IconTheme.of(ctx).color),
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(isExportingPdf ? 'Generating PDF...' : 'Generate PDF',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: isExportingPdf ? null : onExportPdf,
      ),
    ),
    const SizedBox(height: 24),
  ];
}

Widget _errorCard(String message) => Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to generate statement', style: _bold),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ]),
      ),
    );

class _StatementFilters extends StatelessWidget {
  final bool isLoadingClients;
  final ValueNotifier<List<Client>> clients;
  final ValueNotifier<List<Project>> projectsForClient;
  final Client? selectedClient;
  final Set<int> selectedProjectIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<Client?> onClientChanged;
  final void Function(int, bool) onProjectToggled;
  final void Function(bool isStart) onPickDate;
  final void Function(bool isStart) onClearDate;
  const _StatementFilters({
    required this.isLoadingClients,
    required this.clients,
    required this.projectsForClient,
    required this.selectedClient,
    required this.selectedProjectIds,
    required this.dateFrom,
    required this.dateTo,
    required this.onClientChanged,
    required this.onProjectToggled,
    required this.onPickDate,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _clientDropdown(),
              const SizedBox(height: 16),
              _projectsSection(),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _dateField(true)),
                const SizedBox(width: 12),
                Expanded(child: _dateField(false)),
              ]),
            ],
          ),
        ),
      );

  Widget _clientDropdown() {
    if (isLoadingClients) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    return ValueListenableBuilder<List<Client>>(
      valueListenable: clients,
      builder: (_, list, __) {
        final items = {for (final c in list) c.id: c}.values.toList();
        return DropdownButtonFormField<Client>(
          value: selectedClient,
          decoration: const InputDecoration(labelText: 'Client'),
          isExpanded: true,
          items: items
              .map((c) =>
                  DropdownMenuItem<Client>(value: c, child: Text(c.name)))
              .toList(),
          onChanged: onClientChanged,
        );
      },
    );
  }

  Widget _projectsSection() => ValueListenableBuilder<List<Project>>(
        valueListenable: projectsForClient,
        builder: (_, projects, __) {
          if (selectedClient == null) {
            return const Text('Select a client to choose projects.',
                style: _grey);
          }
          if (projects.isEmpty) {
            return const Text('No projects for this client.', style: _grey);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Projects',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          selectedProjectIds.isEmpty
                              ? 'All projects'
                              : '${selectedProjectIds.length} selected',
                          style: _greySmall),
                    ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: projects.where((p) => p.id != null).map((p) {
                    final id = p.id!;
                    return FilterChip(
                      label: Text(p.projectName),
                      selected: selectedProjectIds.contains(id),
                      onSelected: (sel) => onProjectToggled(id, sel),
                    );
                  }).toList(),
                ),
              ]);
        },
      );

  Widget _dateField(bool isStart) {
    final value = isStart ? dateFrom : dateTo;
    return InkWell(
      onTap: () => onPickDate(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: isStart ? 'Date From' : 'Date To',
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onClearDate(isStart)),
        ),
        child: Text(value == null ? 'Any' : _dateFmt.format(value)),
      ),
    );
  }
}

Widget _summaryChip(String label, double value, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _greyLabel),
        Text(_currency.format(value),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );

class _ProjectStatementCard extends StatelessWidget {
  final ProjectStatement ps;
  const _ProjectStatementCard({required this.ps});

  Widget _line(StatementLine l) {
    final amountColor = l.amount < 0 ? Colors.green[700] : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(_dateFmt.format(l.date))),
        SizedBox(width: 70, child: Text(l.type)),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.description),
                if (l.reference.isNotEmpty)
                  Text(l.reference,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
        ),
        SizedBox(
            width: 90,
            child: Text(_currency.format(l.amount),
                textAlign: TextAlign.right,
                style: TextStyle(color: amountColor))),
        SizedBox(
            width: 90,
            child: Text(_currency.format(l.runningBalance),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFixedPrice = ps.project.pricingModel == 'fixed';
    final pendingLabel = isFixedPrice ? 'Uninvoiced' : 'Pending';
    return Card(
      child: ExpansionTile(
        title: Text(ps.project.projectName, style: _bold),
        subtitle: Text(
          'Outstanding: ${_currency.format(ps.outstanding)}  •  '
          '$pendingLabel: ${_currency.format(ps.pendingTotal)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    _summaryChip('Billed', ps.billedAmount),
                    _summaryChip('Paid', ps.paidAmount),
                    _summaryChip('Outstanding', ps.outstanding,
                        color: Colors.orange[800]),
                    if (isFixedPrice)
                      _summaryChip(
                          'Uninvoiced Contract Balance', ps.pendingTotal,
                          color: Colors.blueGrey[700])
                    else ...[
                      _summaryChip('Pending Labour', ps.pendingLabour),
                      _summaryChip('Pending Materials', ps.pendingMaterials),
                      _summaryChip('Pending Total', ps.pendingTotal,
                          color: Colors.blueGrey[700]),
                    ],
                  ]),
                    const Divider(height: 24),
                    const DefaultTextStyle(
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      child: Row(children: [
                        SizedBox(width: 90, child: Text('Date')),
                        SizedBox(width: 70, child: Text('Type')),
                        Expanded(child: Text('Description')),
                        SizedBox(
                            width: 90,
                            child: Text('Amount', textAlign: TextAlign.right)),
                        SizedBox(
                            width: 90,
                            child:
                                Text('Balance', textAlign: TextAlign.right)),
                      ]),
                    ),
                    if (ps.lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No invoices or payments in this period.',
                            style: _greySmall),
                      )
                    else
                      ...ps.lines.map(_line),
                  ]),
            ),
          ],
        ),
      );
  }
}

class _GrandTotalsCard extends StatelessWidget {
  final ClientStatement statement;
  const _GrandTotalsCard({required this.statement});

  Widget _row(String label, double value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(_currency.format(value),
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.blueGrey[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Grand Totals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _row('Total Billed', statement.totalBilled),
              _row('Total Paid', statement.totalPaid),
              _row('Outstanding', statement.totalOutstanding,
                  color: Colors.orange[800]),
              _row('Pending (Unbilled)', statement.totalPending,
                  color: Colors.blueGrey[800]),
            ],
          ),
        ),
      );
}
