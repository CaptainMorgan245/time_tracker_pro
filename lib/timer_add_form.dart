// lib/timer_add_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker_pro/input_formatters.dart';import 'package:time_tracker_pro/models.dart';

class TimerAddForm extends StatefulWidget {
  final ValueNotifier<List<Project>> projectsNotifier;
  final ValueNotifier<List<Employee>> employeesNotifier;

  final Function(Project?, Employee?, String?, DateTime?, DateTime?) onSubmit;
  final bool isLiveTimerForm;
  final Function(String, Project?, Employee?, String?, DateTime?, DateTime?) onUpdate;

  const TimerAddForm({
    super.key,
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

  Future<void> _showStartTimeInputDialog() async {
    final timeController = TextEditingController();
    final now = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Start Time'),
        content: TextField(
          controller: timeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          // YOUR REFINED DECORATION
          decoration: const InputDecoration(
            labelText: 'Start Time (4-digit 24-hour)',
            hintText: 'HHmm, e.g., 0830',
            helperText: 'Add 12 for 24 hr time.\nExample: 2:30 PM = 1430',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed == true && timeController.text.length == 4) { // Check length
      try {
        final hours = int.parse(timeController.text.substring(0, 2));
        final minutes = int.parse(timeController.text.substring(2));

        if (hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60) {
          setState(() {
            _selectedStartTime = DateTime(now.year, now.month, now.day, hours, minutes);
          });
          _submit(); // Immediately submit after setting time
        } else {
          // Show error for invalid time range
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid time. Hours 00-23, Mins 00-59.')),
            );
          }
        }
      } catch (e) {
        // Show error for parsing issue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid format. Please use HHmm.')),
          );
        }
      }
    } else if (confirmed == true && timeController.text.isNotEmpty) {
      // Handle incomplete input like "830"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter 4 digits (HHmm).')),
        );
      }
    }
  }

  Future<void> _selectStartTime() async {
    await _showStartTimeInputDialog();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    const inputBorder = OutlineInputBorder();

    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<List<Project>>(
                    valueListenable: widget.projectsNotifier,
                    builder: (context, projects, child) {
                      if (_selectedProject != null && !projects.any((p) => p.id == _selectedProject!.id)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedProject = null;
                          });
                        });
                      }

                      return DropdownButtonFormField<Project>(
                        decoration: const InputDecoration(
                          border: inputBorder,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          labelText: 'Select Project',
                        ),
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
                  child: ValueListenableBuilder<List<Employee>>(
                    valueListenable: widget.employeesNotifier,
                    builder: (context, employees, child) {
                      if (_selectedEmployee != null && !employees.any((e) => e.id == _selectedEmployee!.id)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedEmployee = null;
                          });
                        });
                      }

                      return DropdownButtonFormField<Employee?>(
                        decoration: const InputDecoration(
                          border: inputBorder,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          labelText: 'Select Employee',
                        ),
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
                    decoration: const InputDecoration(
                      hintText: "Enter details about work performed...",
                      border: inputBorder,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectStartTime,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Set Start'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedStartTime = null;
                        });
                        _submit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(_editingRecordId != null ? 'Update' : 'Start Now'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
