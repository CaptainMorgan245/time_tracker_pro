// lib/project_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'dart:async';
import 'package:time_tracker_pro/dropdown_repository.dart';

class ProjectRepository {
  final dbHelper = DatabaseHelperV2.instance;
  final DropdownRepository dropdownRepo = DropdownRepository();

  // =========================================================================
  // ANALYTICS METHODS
  // =========================================================================

  Future<ProjectSummaryViewModel> _createSummaryViewModel(int projectId) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> projectMaps = await db.query(
        'projects', where: 'id = ?', whereArgs: [projectId]);

    if (projectMaps.isEmpty) {
      throw Exception("Project not found for ID: $projectId");
    }

    final projectMap = projectMaps.first;
    final summaryDetails = await dropdownRepo.getProjectSummaryDetails(projectId);

    // --- Data Extraction and Financial Calculations (Final Logic) ---

    final String projectName = projectMap['project_name'] as String;
    final String pricingModel = projectMap['pricing_model'] as String? ?? 'hourly';

    final String? clientName = summaryDetails['client_name'] as String?;
    final double totalHours = (summaryDetails['total_hours'] as num?)?.toDouble() ?? 0.0;
    final double totalExpenses = (summaryDetails['total_expenses'] as num?)?.toDouble() ?? 0.0;

    // Rate/Price Logic
    final double billedHourlyRate = (projectMap['billed_hourly_rate'] as num?)?.toDouble() ?? 0.0;
    final double fixedPrice = (projectMap['project_price'] as num?)?.toDouble() ?? 0.0;

    // Billed Rate for the card (either hourly or fixed)
    final double billedRate = (pricingModel == 'hourly') ? billedHourlyRate : fixedPrice;

    final double totalLabourCost;
    final double totalBilledValue;

    if (pricingModel == 'fixed' || pricingModel == 'project_based') {
      // For Fixed Price: Total Billed Value is the Fixed Price.
      // Provisional Labour cost is set to 0.0 (safest proxy).
      totalBilledValue = fixedPrice;
      totalLabourCost = 0.0;
    } else {
      // For Hourly: Total Billed Value is Hours * Billed Hourly Rate.
      // Provisional Labour Cost is set to Hours * Billed Hourly Rate (Safest proxy until internal rates are calculated).
      totalBilledValue = totalHours * billedHourlyRate;
      totalLabourCost = totalHours * billedHourlyRate;
    }

    // Provisional P/L: Billed Value - Labour Cost Proxy - Expenses
    final profitLoss = totalBilledValue - totalLabourCost - totalExpenses;
    // -----------------------------------------------------------------------

    return ProjectSummaryViewModel(
      projectId: projectId,
      projectName: projectName,
      clientName: clientName,
      pricingModel: pricingModel,
      billedRate: billedRate,
      totalHours: totalHours,
      totalExpenses: totalExpenses,
      totalLabourCost: totalLabourCost,
      totalBilledValue: totalBilledValue,
      profitLoss: profitLoss,
    );
  }

  // Implements getProjectSummary(int projectId)
  Future<ProjectSummaryViewModel?> getProjectSummary(int projectId) async {
    try {
      return await _createSummaryViewModel(projectId);
    } catch (e) {
      return null;
    }
  }

  // Implements getProjectListReport({required bool activeOnly})
  Future<List<ProjectSummaryViewModel>> getProjectListReport({required bool activeOnly}) async {
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> projectMaps = await db.query(
      'projects',
      columns: ['id'], // Only need the IDs
      where: 'is_completed = ?',
      whereArgs: [activeOnly ? 0 : 1],
    );

    final futures = projectMaps.map((map) {
      final projectId = map['id'] as int;
      return _createSummaryViewModel(projectId);
    }).toList();

    final results = await Future.wait(futures);
    return results.whereType<ProjectSummaryViewModel>().toList();
  }

  // =========================================================================
  // CRUD & UTILITY METHODS (Restored functionality)
  // =========================================================================

  // Implements: getProjects()
  Future<List<Project>> getProjects() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('projects');
    return List.generate(maps.length, (i) => Project.fromMap(maps[i]));
  }

  // Implements: insertProject(newProject)
  Future<int> insertProject(Project project) async {
    final db = await dbHelper.database;
    return await db.insert('projects', project.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Implements: updateProject(project)
  Future<int> updateProject(Project project) async {
    final db = await dbHelper.database;
    return await db.update(
      'projects', project.toMap(), where: 'id = ?', whereArgs: [project.id],
    );
  }

  // Implements: deleteProject(id)
  Future<int> deleteProject(int id) async {
    final db = await dbHelper.database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // Implements: hasAssociatedRecords(id)
  Future<bool> hasAssociatedRecords(int projectId) async {
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> timeMaps = await db.query(
      'time_entries', where: 'project_id = ?', whereArgs: [projectId], limit: 1,
    );
    if (timeMaps.isNotEmpty) return true;

    final List<Map<String, dynamic>> materialMaps = await db.query(
      'materials', where: 'project_id = ?', whereArgs: [projectId], limit: 1,
    );
    if (materialMaps.isNotEmpty) return true;

    return false;
  }
}