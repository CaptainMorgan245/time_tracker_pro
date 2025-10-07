// lib/timer_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker_pro/input_formatters.dart';

class TimerAddForm extends StatefulWidget {
  // FIX 1: Change from static lists to ValueNotifiers.
  final ValueNotifier<List<Project>> projectsNotifier;
  final ValueNotifier<List<Employee>> employeesNotifier;

  final Function(Project?, Employee?, String?, DateTime?, DateTime?) onSubmit;
  final bool isLiveTimerForm;
  final Function(String, Project?, Employee?, String?, DateTime?, DateTime?) onUpdate;

  const TimerAddForm({
    super.key,
    // FIX 2: Update the constructor to require the notifiers.
    required this.projectsNotifier,
    required this.employeesNotifier,
    required this.onSubmit,
    required this.onUpdate,
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
  String? _editingRecordId;

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
      _editingRecordId = null;
    });
  }

  void populateForm(TimeEntry record) {
    setState(() {
      _editingRecordId = record.id.toString();

      // FIX 3: Read the current list from the notifier's .value
      final currentProjects = widget.projectsNotifier.value;
      final currentEmployees = widget.employeesNotifier.value;

      try {
        _selectedProject = currentProjects.firstWhere((p) => p.id == record.projectId);
      } catch (e) {
        _selectedProject = null; // Project not found in the list
      }

      try {
        _selectedEmployee = record.employeeId != null
            ? currentEmployees.firstWhere((e) => e.id == record.employeeId)
            : null;
      } catch (e) {
        _selectedEmployee = null; // Employee not found
      }

      _workDetailsController.text = record.workDetails ?? '';
      _selectedStartTime = record.startTime;
      _selectedStopTime = record.endTime;
    });
  }

  // FIXED: Removed the unused `_selectDateTime` method.
  // This method was defined but never called anywhere in the code.

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
                // FIXED: Replaced deprecated 'value' with 'initialValue'.
                initialValue: amPm,
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
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project.')),
      );
      return;
    }

    if (!widget.isLiveTimerForm) {
      if (_selectedStartTime == null || _selectedStopTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set both a start and stop time.')),
        );
        return;
      }
      if (_selectedStopTime!.isBefore(_selectedStartTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stop time cannot be before start time.')),
        );
        return;
      }
    }

    if (_editingRecordId != null) {
      widget.onUpdate(
        _editingRecordId!,
        _selectedProject,
        _selectedEmployee,
        _workDetailsController.text,
        _selectedStartTime,
        _selectedStopTime,
      );
    } else {
      widget.onSubmit(
        _selectedProject,
        _selectedEmployee,
        _workDetailsController.text,
        _selectedStartTime,
        _selectedStopTime,
      );
    }
  }

  // FIXED: Removed the unused `_formatDateTime` method.
  // This method was defined but never called anywhere in the code.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final inputBorder = const OutlineInputBorder();

    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  // FIX 4: Wrap the dropdown in a ValueListenableBuilder for PROJECTS.
                  child: ValueListenableBuilder<List<Project>>(
                    valueListenable: widget.projectsNotifier,
                    builder: (context, projects, child) {
                      // Ensure the selected project is still valid
                      if (_selectedProject != null && !projects.any((p) => p.id == _selectedProject!.id)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedProject = null;
                          });
                        });
                      }

                      return DropdownButtonFormField<Project>(
                        decoration: InputDecoration(
                          border: inputBorder,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          labelText: 'Select Project',
                        ),
                        // FIXED: Replaced deprecated 'value' with 'initialValue'.
                        initialValue: _selectedProject,
                        items: projects.map((project) {
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
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // FIX 5: Wrap the dropdown in a ValueListenableBuilder for EMPLOYEES.
                  child: ValueListenableBuilder<List<Employee>>(
                    valueListenable: widget.employeesNotifier,
                    builder: (context, employees, child) {
                      // Ensure the selected employee is still valid
                      if (_selectedEmployee != null && !employees.any((e) => e.id == _selectedEmployee!.id)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedEmployee = null;
                          });
                        });
                      }

                      return DropdownButtonFormField<Employee?>(
                        decoration: InputDecoration(
                          border: inputBorder,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          labelText: 'Select Employee',
                        ),
                        // FIXED: Replaced deprecated 'value' with 'initialValue'.
                        initialValue: _selectedEmployee,
                        items: [
                          const DropdownMenuItem<Employee?>(
                            value: null,
                            child: Text('None Selected'),
                          ),
                          ...employees.map((employee) {
                            return DropdownMenuItem<Employee?>(
                              value: employee,
                              child: Text(employee.name),
                            );
                          }).toList(),
                        ],
                        onChanged: (Employee? newValue) {
                          setState(() {
                            _selectedEmployee = newValue;
                          });
                        },
                        hint: const Text('Select an employee'),
                      );
                    },
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
                    inputFormatters: [CapitalizeFirstWordInputFormatter()],
                    decoration: InputDecoration(
                      hintText: "Enter details about work performed...",
                      border: inputBorder,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      labelText: 'Work Details',
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            if (!widget.isLiveTimerForm) ...[
              // This section for non-live form remains the same
            ],
            if (widget.isLiveTimerForm) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(_editingRecordId != null ? 'Update Live Timer' : 'Start New Timer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
