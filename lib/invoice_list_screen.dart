// lib/invoice_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/create_invoice_screen.dart';
import 'package:time_tracker_pro/invoice_detail_screen.dart';
import 'extras_invoice_screen.dart';

// start class: InvoiceListScreen
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}
// end class: InvoiceListScreen

// start class: _InvoiceListScreenState
class _InvoiceListScreenState extends State<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final DatabaseHelperV2 _dbHelper = DatabaseHelperV2.instance;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');

  // Tab indices
  static const int _tabInvoices = 0;
  static const int _tabPaid = 1;
  static const int _tabEstimates = 2;

  List<Invoice> _activeInvoices = [];
  List<Invoice> _paidInvoices = [];
  List<Invoice> _voidedInvoices = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showVoided = false;

  Map<String, List<Invoice>> _groupedActive = {};
  Map<String, List<Invoice>> _groupedPaid = {};
  Map<String, List<Invoice>> _groupedVoided = {};

  @override
  void initState() {
    super.initState();
    _showVoided = false; // Reset on entry
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    
    // Listen for database changes
    _dbHelper.databaseNotifier.addListener(_loadInvoices);
    
    _loadInvoices();
  }

  @override
  void dispose() {
    _dbHelper.databaseNotifier.removeListener(_loadInvoices);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final all = await _invoiceRepository.getAllInvoices(includeDeleted: _showVoided);

      final active = all.where((i) => !i.isPaid && !i.isDeleted).toList();
      final paid = all.where((i) => i.isPaid && !i.isDeleted).toList();
      final voided = all.where((i) => i.isDeleted).toList();

      active.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      paid.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      voided.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

      if (mounted) {
        setState(() {
          _activeInvoices = active;
          _paidInvoices = paid;
          _voidedInvoices = voided;
          _groupedActive = _groupByProject(active);
          _groupedPaid = _groupByProject(paid);
          _groupedVoided = _groupByProject(voided);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load invoices: $e';
          _isLoading = false;
        });
      }
    }
  }

  Map<String, List<Invoice>> _groupByProject(List<Invoice> invoices) {
    final grouped = <String, List<Invoice>>{};
    for (final inv in invoices) {
      final key = inv.projectName ?? 'No Project';
      grouped.putIfAbsent(key, () => []).add(inv);
    }
    return grouped;
  }

  // ── Page title ────────────────────────────────────────────────────────────

  String get _pageTitle {
    switch (_tabController.index) {
      case _tabPaid:
        return 'Paid Invoices';
      case _tabEstimates:
        return 'Estimates';
      default:
        return 'Invoices';
    }
  }

  // ── Fixed header ──────────────────────────────────────────────────────────

  Widget _buildFixedHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showVoided ? 'Voided Invoices' : _pageTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Show Voided', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _showVoided,
                      onChanged: (val) {
                        setState(() => _showVoided = val);
                        _loadInvoices();
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _loadInvoices,
                ),
              ],
            ),
          ],
        ),
        if (!_showVoided) ...[
          const SizedBox(height: 12),
          _buildNavButtons(),
        ],
      ],
    );
  }

  // ── Nav buttons — context sensitive ──────────────────────────────────────

  Widget _buildNavButtons() {
    final int current = _tabController.index;

    if (current == _tabInvoices) {
      return Row(
        children: [
          Expanded(child: _actionButton('Paid Invoices', Icons.check_circle_outline, () => _tabController.animateTo(_tabPaid), Colors.green[700]!)),
          const SizedBox(width: 8),
          Expanded(child: _actionButton('Estimates', Icons.calculate_outlined, () => _tabController.animateTo(_tabEstimates), Colors.purple[700]!)),
          const SizedBox(width: 8),
          Expanded(child: _actionButton('Fixed Price Invoice', Icons.add, _onCreateInvoice, Colors.blue[700]!)),
          const SizedBox(width: 8),
          Expanded(child: _actionButton('Extras Invoice', Icons.checklist, _onCreateExtrasInvoice, Colors.orange[700]!)),
        ],
      );
    }

    if (current == _tabPaid) {
      return Row(
        children: [
          Expanded(child: _actionButton('Invoices', Icons.receipt_long, () => _tabController.animateTo(_tabInvoices), Colors.blue[700]!)),
          const SizedBox(width: 8),
          Expanded(child: _actionButton('Estimates', Icons.calculate_outlined, () => _tabController.animateTo(_tabEstimates), Colors.purple[700]!)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _actionButton('Invoices', Icons.receipt_long, () => _tabController.animateTo(_tabInvoices), Colors.blue[700]!)),
        const SizedBox(width: 8),
        Expanded(child: _actionButton('Paid Invoices', Icons.check_circle_outline, () => _tabController.animateTo(_tabPaid), Colors.green[700]!)),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────────────────────────

  Widget _buildStatusChip(Invoice invoice) {
    String label;
    Color color;

    if (invoice.isDeleted) {
      label = 'Void';
      color = Colors.red;
    } else if (invoice.isPaid) {
      label = 'Paid';
      color = Colors.green;
    } else if (invoice.isSent) {
      label = 'Sent';
      color = Colors.blue;
    } else {
      label = 'Draft';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Invoice card ──────────────────────────────────────────────────────────

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onInvoiceTap(invoice),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Invoice: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: invoice.invoiceNumber),
                    ]),
                  ),
                  _buildStatusChip(invoice),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(TextSpan(children: [
                    const TextSpan(
                        text: 'Client: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: invoice.clientName ?? '—'),
                  ])),
                  Text.rich(TextSpan(children: [
                    const TextSpan(
                        text: 'Date: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: DateFormat('MMM d, yyyy')
                            .format(invoice.invoiceDate)),
                  ])),
                ],
              ),
              if (invoice.isDeleted && invoice.deletedReasonCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Reason: ${invoice.deletedReasonCode}',
                  style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                ),
              ],
              const Divider(height: 24, thickness: 1.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    invoice.isPaid ? 'Amount Paid:' : 'Amount Due:',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _currencyFormat.format(invoice.totalAmount),
                    style: TextStyle(
                      color: invoice.isDeleted 
                          ? Colors.red 
                          : (invoice.isPaid ? Colors.green : Theme.of(context).primaryColor),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (invoice.isPaid && invoice.paymentDate != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Paid ${DateFormat('MMM d, yyyy').format(invoice.paymentDate!)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Project group ─────────────────────────────────────────────────────────

  Widget _buildProjectGroup(String projectName, List<Invoice> invoices, {Color? headerColor}) {
    final totalAmount =
        invoices.fold<double>(0, (sum, inv) => sum + inv.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (headerColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: (headerColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                projectName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _currencyFormat.format(totalAmount),
                style: TextStyle(
                  color: headerColor ?? Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...invoices.map(_buildInvoiceCard),
      ],
    );
  }

  // ── Empty states ──────────────────────────────────────────────────────────

  Widget _buildEmptyInvoices() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'No active invoices',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap New Invoice to create your first invoice.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPaid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'No paid invoices yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid invoices will appear here.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatesComingSoon() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'Estimates',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context)
                        .primaryColor
                        .withValues(alpha: 0.25)),
              ),
              child: Text(
                'Coming Soon',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Project estimates and quote generation\nwill be available in a future update.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  Widget _buildActiveInvoices() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center));
    }
    
    if (_activeInvoices.isEmpty) return _buildEmptyInvoices();

    final projectNames = _groupedActive.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: projectNames.length,
      itemBuilder: (context, index) {
        final name = projectNames[index];
        return _buildProjectGroup(name, _groupedActive[name]!);
      },
    );
  }

  Widget _buildPaidInvoices() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_paidInvoices.isEmpty) return _buildEmptyPaid();

    final projectNames = _groupedPaid.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: projectNames.length,
      itemBuilder: (context, index) {
        final name = projectNames[index];
        return _buildProjectGroup(name, _groupedPaid[name]!);
      },
    );
  }

  Widget _buildVoidedInvoices() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center));
    }
    
    if (_voidedInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_flipped, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'No voided invoices',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final voidedNames = _groupedVoided.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: voidedNames.length,
      itemBuilder: (context, index) {
        final name = voidedNames[index];
        return _buildProjectGroup(name, _groupedVoided[name]!, headerColor: Colors.red);
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onInvoiceTap(Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id!),
      ),
    );
  }

  Future<void> _onCreateInvoice() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    );
    if (result == true) _loadInvoices();
  }

  void _onCreateExtrasInvoice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExtrasInvoiceScreen()),
    ).then((result) {
      if (result == true) _loadInvoices();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          children: [
            _buildFixedHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: _showVoided 
                ? _buildVoidedInvoices()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveInvoices(),
                      _buildPaidInvoices(),
                      _buildEstimatesComingSoon(),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
// end class: _InvoiceListScreenState
