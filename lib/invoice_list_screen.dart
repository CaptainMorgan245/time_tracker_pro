// lib/invoice_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/invoice_repository.dart';
import 'package:time_tracker_pro/invoice_service.dart';

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
  final InvoiceService _invoiceService = InvoiceService.instance;
  final NumberFormat _currencyFormat =
  NumberFormat.currency(locale: 'en_US', symbol: '\$');

  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, List<Invoice>> _groupedInvoices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final invoices = await _invoiceRepository.getAllInvoices();
      final grouped = <String, List<Invoice>>{};
      for (final inv in invoices) {
        final key = inv.projectName ?? 'No Project';
        grouped.putIfAbsent(key, () => []).add(inv);
      }
      for (final list in grouped.values) {
        list.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      }
      setState(() {
        _invoices = invoices;
        _groupedInvoices = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load invoices: $e';
        _isLoading = false;
      });
    }
  }

  // ── Fixed header with tab selector ───────────────────────────────────────

  Widget _buildFixedHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tabController.index == 0 ? 'Invoices' : 'Estimates',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadInvoices,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Invoices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tabController.index == 0
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                  foregroundColor:
                  _tabController.index == 0 ? Colors.white : Colors.black54,
                  elevation: _tabController.index == 0 ? 3 : 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Estimates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tabController.index == 1
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                  foregroundColor:
                  _tabController.index == 1 ? Colors.white : Colors.black54,
                  elevation: _tabController.index == 1 ? 3 : 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Status chip ──────────────────────────────────────────────────────────

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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
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

  // ── Invoice card ─────────────────────────────────────────────────────────

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
                      color: invoice.isPaid
                          ? Colors.green
                          : Theme.of(context).primaryColor,
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

  // ── Project group header ─────────────────────────────────────────────────

  Widget _buildProjectGroup(String projectName, List<Invoice> invoices) {
    final totalBilled =
    invoices.fold<double>(0, (sum, inv) => sum + inv.totalAmount);
    final unpaidCount =
        invoices.where((i) => !i.isPaid && !i.isDeleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                projectName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(totalBilled),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unpaidCount > 0)
                    Text(
                      '$unpaidCount unpaid',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.orangeAccent),
                    ),
                ],
              ),
            ],
          ),
        ),
        ...invoices.map(_buildInvoiceCard),
      ],
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

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
              'No invoices yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap New Invoice below to get started.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Estimates coming soon ────────────────────────────────────────────────

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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.25)),
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

  // ── Invoice list body ────────────────────────────────────────────────────

  Widget _buildInvoiceContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_invoices.isEmpty) {
      return _buildEmptyInvoices();
    }

    final projectNames = _groupedInvoices.keys.toList()..sort();
    return ListView.builder(
      itemCount: projectNames.length,
      itemBuilder: (context, index) {
        final name = projectNames[index];
        return _buildProjectGroup(name, _groupedInvoices[name]!);
      },
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _onInvoiceTap(Invoice invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Invoice detail coming — ${invoice.invoiceNumber}')),
    );
  }

  void _onCreateInvoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create invoice — coming next')),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInvoiceContent(),
                  _buildEstimatesComingSoon(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
        onPressed: _onCreateInvoice,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      )
          : null,
    );
  }
}
// end class: _InvoiceListScreenState