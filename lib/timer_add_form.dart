// lib/timer_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:intl/intl.dart';

class TimerAddForm extends StatefulWidget {
  final List<Project> projects;
  final List<Employee> employees;
  final Function(Project?, Employee?, String, DateTime?, DateTime?) onSubmit;
  final bool isLiveTimerForm;

  const TimerAddForm({
    super.key,
    required this.projects,
    required this.employees,
    required this.onSubmit,
    this.isLiveTimerForm = true,
  });

  @override
  State<TimerAddForm> createState() => TimerAddFormState();
}

class TimerAddFormState extends State<TimerAddForm> {
  Project? _selectedProject;
  Employee? _selectedEmployee;
  final TextEditingController _workDetailsController = TextEditingController();
  DateTime? _selectedStartTime;
  DateTime? _selectedStopTime;

  @override
  void dispose() {
    _workDetailsController.dispose();
    super.dispose();
  }

  void resetForm() {
    setState(() {
      _selectedProject = null;
      _selectedEmployee = null;
      _workDetailsController.clear();
      _selectedStartTime = null;
      _selectedStopTime = null;
    });
  }

  void populateForm(Project project, Employee employee, String workDetails) {
    setState(() {
      _selectedProject = project;
      _selectedEmployee = employee;
      _workDetailsController.text = workDetails;
    });
  }

  Future<void> _selectDateTime(
      BuildContext context,
      bool isStartTime,
      ) async {
    DateTime? initialDate;
    if (isStartTime) {
      initialDate = _selectedStartTime ?? DateTime.now();
    } else {
      initialDate = _selectedStopTime ?? _selectedStartTime ?? DateTime.now();
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      _showTimeInputDialog(context, isStartTime, pickedDate);
    }
  }

  Future<void> _showTimeInputDialog(BuildContext context, bool isStartTime, DateTime pickedDate) async {
    final TextEditingController hourController = TextEditingController();
    final TextEditingController minuteController = TextEditingController();
    String? amPm = 'AM';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isStartTime ? 'Set Start Time' : 'Set Stop Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hourController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Hour (01-12)'),
              ),
              TextField(
                controller: minuteController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minute (00-59)'),
              ),
              DropdownButtonFormField<String>(
                value: amPm,
                items: ['AM', 'PM'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  amPm = newValue;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () {
                final int hour = int.tryParse(hourController.text) ?? 0;
                final int minute = int.tryParse(minuteController.text) ?? 0;
                if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid time. Please enter a valid hour and minute.')),
                  );
                  return;
                }
                int finalHour = hour;
                if (amPm == 'PM' && hour != 12) {
                  finalHour += 12;
                }
                if (amPm == 'AM' && hour == 12) {
                  finalHour = 0;
                }

                final newDateTime = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  finalHour,
                  minute,
                );

                setState(() {
                  if (isStartTime) {
                    _selectedStartTime = newDateTime;
                  } else {
                    _selectedStopTime = newDateTime;
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    widget.onSubmit(
      _selectedProject,
      _selectedEmployee,
      _workDetailsController.text,
      widget.isLiveTimerForm ? null : _selectedStartTime,
      widget.isLiveTimerForm ? null : _selectedStopTime,
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Project>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      label: Text('Select Project'),
                    ),
                    value: _selectedProject,
                    items: widget.projects.map((project) {
                      return DropdownMenuItem<Project>(
                        value: project,
                        child: Text(project.projectName),
                      );
                    }).toList(),
                    onChanged: (Project? newValue) {
                      setState(() {
                        _selectedProject = newValue;
                      });
                    },
                    hint: const Text('Select a project'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Employee>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      label: Text('Select Employee'),
                    ),
                    value: _selectedEmployee,
                    items: widget.employees.map((employee) {
                      return DropdownMenuItem<Employee>(
                        value: employee,
                        child: Text(employee.name),
                      );
                    }).toList(),
                    onChanged: (Employee? newValue) {
                      setState(() {
                        _selectedEmployee = newValue;
                      });
                    },
                    hint: const Text('Select an employee'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _workDetailsController,
                    decoration: const InputDecoration(
                      hintText: "Enter details about work performed...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      label: Text('Work Details'),
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            if (!widget.isLiveTimerForm) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDateTime(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Set Start Time'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDateTime(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Set Stop Time'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Add Time Record'),
                    ),
                  ),
                ],
              ),
              if (_selectedStartTime != null || _selectedStopTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'Start: ${_formatDateTime(_selectedStartTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Stop: ${_formatDateTime(_selectedStopTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
            if (widget.isLiveTimerForm) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Start New Timer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}