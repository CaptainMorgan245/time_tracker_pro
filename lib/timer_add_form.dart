// lib/timer_add_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';

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

  DateTime _selectedDate = DateTime.now();

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
      _selectedDate = DateTime.now();
    });
  }

  void clearEmployeeAndDetails() {
    setState(() {
      _selectedEmployee = null;
      _workDetailsController.clear();
      _selectedStartTime = null;
      _selectedStopTime = null;
      _editingRecordId = null;
      // Keep _selectedProject and _selectedDate
    });
  }

  /// Pre-fills the form for starting a new timer based on a previous record.
  /// This only sets the project and employee, and clears all other fields
  /// to ensure the form is in a "new entry" state.
  void prefillForNewTimer(Project? project, Employee? employee) {
    setState(() {
      // First, reset everything to a clean slate.
      _editingRecordId = null;
      _workDetailsController.clear();
      _selectedStartTime = null;
      _selectedStopTime = null;
      _selectedDate = DateTime.now();

      // Then, set only the project and employee.
      _selectedProject = project;
      _selectedEmployee = employee;
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
        _selectedProject = null;
      }
      try {
        _selectedEmployee = record.employeeId != null
            ? currentEmployees.firstWhere((e) => e.id == record.employeeId)
            : null;
      } catch (e) {
        _selectedEmployee = null;
      }
      _workDetailsController.text = record.workDetails ?? '';
      _selectedStartTime = record.startTime;
      _selectedStopTime = record.endTime;
      _selectedDate = record.startTime ?? DateTime.now();
    });
  }

  Future<DateTime?> _showTimeInputDialog({required String title, required DateTime initialDate}) async {
    final timeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: timeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: const InputDecoration(
            labelText: 'Time (4-digit 24-hour)',
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
    if (confirmed == true && timeController.text.length == 4) {
      try {
        final hours = int.parse(timeController.text.substring(0, 2));
        final minutes = int.parse(timeController.text.substring(2));
        if (hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60) {
          return DateTime(initialDate.year, initialDate.month, initialDate.day, hours, minutes);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid time. Hours 00-23, Mins 00-59.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid format. Please use HHmm.')),
          );
        }
      }
    } else if (confirmed == true && timeController.text.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter 4 digits (HHmm).')),
        );
      }
    }
    return null;
  }

  Future<void> _startLiveTimer() async {
    final time = await _showTimeInputDialog(title: 'Set Start Time', initialDate: DateTime.now());
    if (time != null) {
      setState(() {
        _selectedStartTime = time;
      });
      _submit();
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        if (_selectedStartTime != null) {
          _selectedStartTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
        }
        if (_selectedStopTime != null) {
          _selectedStopTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _selectedStopTime!.hour, _selectedStopTime!.minute);
        }
      });
    }
  }

  Future<void> _selectManualStartTime() async {
    final time = await _showTimeInputDialog(title: 'Set Start Time', initialDate: _selectedDate);
    if (time != null) {
      setState(() {
        _selectedStartTime = time;
      });
    }
  }

  Future<void> _selectManualStopTime() async {
    final time = await _showTimeInputDialog(title: 'Set Stop Time', initialDate: _selectedDate);
    if (time != null) {
      setState(() {
        _selectedStopTime = time;
      });
    }
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
    final primaryColor = theme.colorScheme.primary;
    const inputBorder = OutlineInputBorder();

    String formatButtonText(DateTime? dt, String prefix) {
      if (dt == null) return 'Set $prefix';
      return '$prefix: ${DateFormat.Hm().format(dt)}';
    }

    final secondaryButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: theme.colorScheme.secondary,
      foregroundColor: theme.colorScheme.onSecondary,
      elevation: 2,
      textStyle: theme.textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

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
                        value: _selectedProject != null && projects.any((p) => p.id == _selectedProject!.id)
                            ? projects.firstWhere((p) => p.id == _selectedProject!.id)
                            : null,
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
            TextFormField(
              controller: _workDetailsController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "Enter details about work performed...",
                border: inputBorder,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                labelText: 'Work Details',
              ),
              maxLines: 1,
            ),

            if (widget.isLiveTimerForm) ...[
              // Live Timer UI
              const SizedBox(height: 16),
              // START --- NEW BUTTON LAYOUT
              Row(
                children: [
                  // This Expanded widget takes up ~30% of the space
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        // "Clear" button takes 25% of this sub-space
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: resetForm,
                            style: secondaryButtonStyle.copyWith(
                              // UPDATED: MaterialStateProperty -> WidgetStateProperty
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 12)), // Smaller font
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "Set Start Time" button takes 75% of this sub-space
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: _startLiveTimer,
                            style: secondaryButtonStyle.copyWith(
                              // UPDATED: MaterialStateProperty -> WidgetStateProperty
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                            ),
                            child: const Text('Set Time', style: TextStyle(fontSize: 12)), // Smaller font
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // This Expanded widget takes up ~70% of the space
                  Expanded(
                    flex: 7,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_editingRecordId == null) {
                          setState(() {
                            _selectedStartTime = DateTime.now();
                          });
                        }
                        _submit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(_editingRecordId != null ? 'Update' : 'Start Timer'),
                    ),
                  ),
                ],
              ),
              // END --- NEW BUTTON LAYOUT
            ] else ...[
              // Manual Entry UI
              const SizedBox(height: 16),
              // ROW 1: Date, Start Time, Stop Time
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(DateFormat.yMd().format(_selectedDate)),
                      onPressed: _selectDate,
                      style: secondaryButtonStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: ElevatedButton(
                      onPressed: _selectManualStartTime,
                      style: secondaryButtonStyle,
                      child: Text(formatButtonText(_selectedStartTime, 'Start')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: ElevatedButton(
                      onPressed: _selectManualStopTime,
                      style: secondaryButtonStyle,
                      child: Text(formatButtonText(_selectedStopTime, 'Stop')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ROW 2: Clear and Add/Update Record
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: resetForm,
                      style: secondaryButtonStyle,
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_editingRecordId != null ? 'Update Record' : 'Add Record'),
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
