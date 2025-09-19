// lib/timer_add_form.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/models.dart';

class TimerAddForm extends StatefulWidget {
  final List<Project> projects;
  final List<Employee> employees;
  final Function(Project?, Employee?, String, String?, String?) onSubmit;

  const TimerAddForm({
    super.key,
    required this.projects,
    required this.employees,
    required this.onSubmit,
  });

  @override
  State<TimerAddForm> createState() => _TimerAddFormState();
}

class _TimerAddFormState extends State<TimerAddForm> {
  Project? _selectedProject;
  Employee? _selectedEmployee;
  final TextEditingController _workDetailsController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _stopTimeController = TextEditingController();
  bool _isManualEntry = false;

  @override
  void initState() {
    super.initState();
    _startTimeController.text = _formatTimeOfDay(TimeOfDay.now());
    _stopTimeController.text = _formatTimeOfDay(TimeOfDay.now());
  }

  @override
  void dispose() {
    _workDetailsController.dispose();
    _startTimeController.dispose();
    _stopTimeController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        controller.text = _formatTimeOfDay(pickedTime);
      });
    }
  }

  void _submit() {
    widget.onSubmit(
      _selectedProject,
      _selectedEmployee,
      _workDetailsController.text,
      _isManualEntry ? _startTimeController.text : null,
      _isManualEntry ? _stopTimeController.text : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manual Time Entry?'),
                Switch(
                  value: _isManualEntry,
                  onChanged: (bool value) {
                    setState(() {
                      _isManualEntry = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: [
                SizedBox(
                  width: 250,
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
                SizedBox(
                  width: 250,
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
                if (_isManualEntry) ...[
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _startTimeController,
                      readOnly: true,
                      onTap: () => _selectTime(context, _startTimeController),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        labelText: 'Start Time',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _stopTimeController,
                      readOnly: true,
                      onTap: () => _selectTime(context, _stopTimeController),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        labelText: 'Stop Time',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workDetailsController,
              decoration: const InputDecoration(
                hintText: "Enter details about work performed...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                label: Text('Work Details'),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(_isManualEntry ? 'Add Time Entry' : 'Start New Timer'),
            ),
          ],
        ),
      ),
    );
  }
}