// lib/project_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:time_tracker_pro/dropdown_repository.dart';
import 'package:time_tracker_pro/services/settings_service.dart';

class ProjectRepository {
  final dbHelper = DatabaseHelperV2.instance;
  final DropdownRepository dropdownRepo = DropdownRepository();
  final SettingsService settingsService = SettingsService.instance;

  // =========================================================================
  // ANALYTICS METHODS
  // =========================================================================

  Future<ProjectSummaryViewModel> _createSummaryViewModel(int projectId) async {
    final db = await dbHelper.database;

    // 1. Fetch core project details
    final List<Map<String, dynamic>> projectMaps = await db.query(
        'projects', where: 'id = ?', whereArgs: [projectId]);

    if (projectMaps.isEmpty) {
      debugPrint('[ProjectRepo Error] Core project data (ID $projectId) not found in projects table.');
      throw Exception("Project not found for ID: $projectId");
    }

    final projectMap = projectMaps.first;

    // 2. Fetch aggregated summary details (time, expenses, client name)
    final summaryDetails = await dropdownRepo.getProjectSummaryDetails(projectId);

    if (summaryDetails.isEmpty || !summaryDetails.containsKey('client_name')) {
      debugPrint('[ProjectRepo Error] Summary data failed or missing keys for ID $projectId. Returning empty result.');
      throw Exception("Summary aggregation failed due to missing keys or empty data.");
    }

    // 3. Fetch Burden Rate (This is the critical line that failed silently)
    // Now correctly calls the stable getBurdenRate method from SettingsService.
    final double companyBurdenRate = await settingsService.getBurdenRate();

    // --- Data Extraction and Financial Calculations ---

    final String projectName = projectMap['project_name'] as String;
    final String pricingModel = projectMap['pricing_model'] as String? ?? 'hourly';

    final String? clientName = summaryDetails['client_name'] as String?;
    final double totalHours = (summaryDetails['total_hours'] as num? ?? 0.0).toDouble();
    final double totalExpenses = (summaryDetails['total_expenses'] as num? ?? 0.0).toDouble();

    final double billedHourlyRate = (projectMap['billed_hourly_rate'] as num? ?? 0.0).toDouble();
    final double fixedPrice = (projectMap['project_price'] as num? ?? 0.0).toDouble();

    final double billedRate = (pricingModel == 'hourly') ? billedHourlyRate : fixedPrice;

    final double totalLabourCost;
    final double totalBilledValue;

    if (pricingModel == 'fixed' || pricingModel == 'project_based') {
      totalLabourCost = totalHours * companyBurdenRate;
      totalBilledValue = fixedPrice;
    } else {
      totalLabourCost = totalHours * billedHourlyRate;
      totalBilledValue = totalHours * billedHourlyRate;
    }

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
      // The error is now trapped and logged correctly.
      debugPrint('*** DEBUG (R-2) DATABASE FAIL: getProjectSummary failed for ID $projectId: $e ***');
      return null;
    }
  }

  // Implements getProjectListReport({required bool activeOnly})
  Future<List<ProjectSummaryViewModel>> getProjectListReport({required bool activeOnly}) async {
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> projectMaps = await db.query(
      'projects',
      columns: ['id'],
      where: 'is_completed = ?',
      whereArgs: [activeOnly ? 0 : 1],
    );

    final futures = projectMaps.map((map) {
      final projectId = map['id'] as int;
      return () async {
        try {
          return await _createSummaryViewModel(projectId);
        } catch (e) {
          debugPrint('[ProjectRepo Warning] Skipping project ID $projectId for list due to error: $e');
          return null;
        }
      }();
    }).toList();

    final results = await Future.wait(futures);
    return results.whereType<ProjectSummaryViewModel>().toList();
  }

  // =========================================================================
  // CRUD & UTILITY METHODS
  // =========================================================================

  Future<List<Project>> getProjects() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('projects');
    return List.generate(maps.length, (i) => Project.fromMap(maps[i]));
  }

  Future<int> insertProject(Project project) async {
    final db = await dbHelper.database;
    return await db.insert('projects', project.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProject(Project project) async {
    final db = await dbHelper.database;
    return await db.update(
      'projects', project.toMap(), where: 'id = ?', whereArgs: [project.id],
    );
  }

  Future<int> deleteProject(int id) async {
    final db = await dbHelper.database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

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
// lib/project_repository.dart