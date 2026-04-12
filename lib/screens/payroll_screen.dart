// lib/screens/payroll_screen.dart

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/settings_service.dart';
import 'package:time_tracker_pro/settings_model.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final AppDatabase _dbHelper = AppDatabase.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  List<Map<String, dynamic>> _payrollData = [];
  bool _isLoading = true;
  SettingsModel? _settings;

  late DateTime _startDate;
  late DateTime _endDate;
  List<Map<String, dynamic>> _projects = [];
  int? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _loadProjects();
    _loadPayrollData();
  }

  Future<void> _loadProjects() async {
    final rows = await _dbHelper.customSelect(
      'SELECT id, project_name as name FROM projects WHERE is_internal = 0 ORDER BY name ASC',
    ).get();
    setState(() {
      _projects = rows.map((r) => r.data).toList();
    });
  }

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);
    try {
      _settings = await SettingsService.instance.loadSettings();
      final String startDateStr = _startDate.toIso8601String();
      final String endDateStr = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String();

      // Query to get active employees with filtered stats using Drift
      final rows = await _dbHelper.customSelect('''
        SELECT 
          e.id, 
          e.name, 
          r.name as role,
          (SELECT IFNULL(SUM(t.final_billed_duration_seconds), 0) 
           FROM time_entries t 
           WHERE t.employee_id = e.id 
             AND t.is_deleted = 0 
             AND t.start_time >= ? 
             AND t.start_time <= ?
             ${_selectedProjectId != null ? 'AND t.project_id = $_selectedProjectId' : ''}) as total_seconds,
          (SELECT IFNULL(SUM((t.final_billed_duration_seconds / 3600.0) * IFNULL(e.hourly_rate, 0)), 0) 
           FROM time_entries t 
           WHERE t.employee_id = e.id 
             AND t.is_deleted = 0 
             AND t.start_time >= ? 
             AND t.start_time <= ?
             ${_selectedProjectId != null ? 'AND t.project_id = $_selectedProjectId' : ''}) as total_earned,
          (SELECT IFNULL(SUM(p.amount), 0) 
           FROM worker_payments p 
           WHERE p.employee_id = e.id 
             AND p.payment_date >= ? 
             AND p.payment_date <= ?) as total_paid
        FROM employees e
        LEFT JOIN roles r ON e.title_id = r.id
        WHERE e.is_deleted = 0
        ORDER BY e.name ASC
      ''', variables: [
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
      ]).get();

      final List<Map<String, dynamic>> payrollWithPayments = [];
      for (var row in rows) {
        final emp = row.data;
        
        final double rawSeconds = (emp['total_seconds'] as num).toDouble();
        final double roundedSeconds = _settings?.applyTimeRounding(rawSeconds) ?? rawSeconds;
        final double hours = roundedSeconds / 3600.0;

        final paymentRows = await _dbHelper.customSelect(
          'SELECT * FROM worker_payments WHERE employee_id = ? AND payment_date >= ? AND payment_date <= ? ORDER BY payment_date DESC',
          variables: [
            Variable.withInt(emp['id']),
            Variable.withString(startDateStr),
            Variable.withString(endDateStr),
          ],
        ).get();
        
        final mutableEmp = Map<String, dynamic>.from(emp);
        mutableEmp['total_hours'] = hours;
        mutableEmp['payments'] = paymentRows.map((r) => r.data).toList();
        payrollWithPayments.add(mutableEmp);
      }

      setState(() {
        _payrollData = payrollWithPayments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payroll data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payroll data: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadPayrollData();
    }
  }

  void _showPaymentDialog(Map<String, dynamic> employee, {WorkerPayment? existingPayment}) {
    final TextEditingController amountController = TextEditingController(
      text: existingPayment?.amount.toString() ?? '',
    );
    final TextEditingController noteController = TextEditingController(
      text: existingPayment?.note ?? '',
    );
    DateTime selectedDate = existingPayment?.paymentDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingPayment == null ? 'Log Payment for ${employee['name']}' : 'Edit Payment for ${employee['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount (\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount.')),
                  );
                  return;
                }

                final payment = WorkerPayment(
                  id: existingPayment?.id,
                  employeeId: employee['id'],
                  paymentDate: selectedDate,
                  amount: amount,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  createdAt: existingPayment?.createdAt ?? DateTime.now(),
                );

                try {
                  if (existingPayment == null) {
                    await _dbHelper.customInsert(
                      'INSERT INTO worker_payments (employee_id, payment_date, amount, note, created_at) VALUES (?, ?, ?, ?, ?)',
                      variables: [
                        Variable.withInt(payment.employeeId),
                        Variable.withString(payment.paymentDate.toIso8601String()),
                        Variable.withReal(payment.amount),
                        Variable(payment.note),
                        Variable.withString(payment.createdAt.toIso8601String()),
                      ],
                    );
                  } else {
                    await _dbHelper.updateWorkerPayment(payment);
                  }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _loadPayrollData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(existingPayment == null ? 'Payment logged successfully.' : 'Payment updated successfully.')),
                    );
                  }
                } catch (e) {
                  debugPrint('Error saving payment: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving payment: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePayment(int paymentId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteWorkerPayment(paymentId);
        _loadPayrollData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment deleted.')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting payment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting payment: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
      ),
      body: SelectionArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(DateFormat('MMM d, yyyy').format(_endDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Project',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedProjectId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Projects'),
                        ),
                        ..._projects.map((p) => DropdownMenuItem<int?>(
                          value: p['id'] as int,
                          child: Text(p['name'] as String),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedProjectId = value);
                        _loadPayrollData();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _payrollData.isEmpty
                      ? const Center(child: Text('No employees found.'))
                      : ListView.builder(
                          itemCount: _payrollData.length,
                          itemBuilder: (context, index) {
                            final emp = _payrollData[index];
                            final double hours = (emp['total_hours'] as num).toDouble();
                            final double earned = (emp['total_earned'] as num).toDouble();
                            final double paid = (emp['total_paid'] as num).toDouble();
                            final double balance = earned - paid;
                            final List<dynamic> payments = emp['payments'];
              
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ExpansionTile(
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            emp['name'],
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            emp['role'] ?? 'No Role Assigned',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showPaymentDialog(emp),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Log Payment'),
                                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatColumn('Hours', hours, isHours: true),
                                      _buildStatColumn('Earned', earned),
                                      _buildStatColumn('Paid', paid),
                                      _buildStatColumn(
                                        'Balance', 
                                        balance, 
                                        color: balance > 0.01 ? Colors.red : (balance < -0.01 ? Colors.green : null)
                                      ),
                                    ],
                                  ),
                                ),
                                children: [
                                  if (payments.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('No payments recorded in this period.', style: TextStyle(fontStyle: FontStyle.italic)),
                                    )
                                  else
                                    ...payments.map((p) {
                                      final paymentModel = WorkerPayment.fromMap(p);
                                      return ListTile(
                                        dense: true,
                                        title: Text('${DateFormat('MMM d, yyyy').format(paymentModel.paymentDate)} - ${_currencyFormat.format(paymentModel.amount)}'),
                                        subtitle: paymentModel.note != null ? Text(paymentModel.note!) : null,
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 18),
                                              onPressed: () => _showPaymentDialog(emp, existingPayment: paymentModel),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                              onPressed: () => _confirmDeletePayment(paymentModel.id!),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, {Color? color, bool isHours = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          isHours ? value.toStringAsFixed(2) : _currencyFormat.format(value),
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
