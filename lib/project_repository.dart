// lib/project_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:time_tracker_pro/dropdown_repository.dart';
import 'package:time_tracker_pro/settings_model.dart';
import 'package:time_tracker_pro/models/analytics_models.dart';

class ProjectRepository {
  final _db = AppDatabase.instance;
  final DropdownRepository dropdownRepo = DropdownRepository();

  // =========================================================================
  // ANALYTICS METHODS
  // =========================================================================

  Future<ProjectSummaryViewModel> _createSummaryViewModel(int projectId) async {
    final projectRows = await _db.customSelect(
      'SELECT * FROM projects WHERE id = ?',
      variables: [Variable.withInt(projectId)],
    ).get();

    if (projectRows.isEmpty) {
      debugPrint('[ProjectRepo Error] Core project data (ID $projectId) not found in projects table.');
      throw Exception("Project not found for ID: $projectId");
    }

    final projectMap = projectRows.first.data;
    final summaryDetails = await dropdownRepo.getProjectSummaryDetails(projectId);

    if (summaryDetails.isEmpty || !summaryDetails.containsKey('client_name')) {
      debugPrint('[ProjectRepo Error] Summary data failed or missing keys for ID $projectId. Returning empty result.');
      throw Exception("Summary aggregation failed due to missing keys or empty data.");
    }

    final double markupPercentage = (projectMap['expense_markup_percentage'] as num?)?.toDouble() ?? 15.0;

    final String projectName = projectMap['project_name'] as String;
    final String pricingModel = projectMap['pricing_model'] as String? ?? 'hourly';
    final String? clientName = summaryDetails['client_name'] as String?;
    final double totalHours = (summaryDetails['total_hours'] as num? ?? 0.0).toDouble();
    final double totalExpenses = (summaryDetails['total_expenses'] as num? ?? 0.0).toDouble();
    final double trueLaborCost = (summaryDetails['total_labor_cost'] as num? ?? 0.0).toDouble();
    final double billedHourlyRate = (projectMap['billed_hourly_rate'] as num? ?? 0.0).toDouble();
    final double fixedPrice = (projectMap['project_price'] as num? ?? 0.0).toDouble();

    final double billedRate = (pricingModel == 'hourly') ? billedHourlyRate : fixedPrice;
    final double laborCost = trueLaborCost;
    final double totalBilledValue;

    if (pricingModel == 'fixed' || pricingModel == 'project_based') {
      totalBilledValue = fixedPrice;
    } else {
      totalBilledValue = totalHours * billedHourlyRate;
    }

    final double materialsCost = totalExpenses * (1 + (markupPercentage / 100));
    final double totalCost = laborCost + materialsCost;
    final double profitLoss = totalBilledValue - totalCost;

    return ProjectSummaryViewModel(
      projectId: projectId,
      projectName: projectName,
      clientName: clientName,
      pricingModel: pricingModel,
      billedRate: billedRate,
      fixedPrice: fixedPrice,
      totalHours: totalHours,
      laborCost: laborCost,
      materialsCost: materialsCost,
      totalCost: totalCost,
      totalBilledValue: totalBilledValue,
      profitLoss: profitLoss,
    );
  }

  Future<ProjectSummaryViewModel?> getProjectSummary(int projectId) async {
    try {
      return await _createSummaryViewModel(projectId);
    } catch (e) {
      debugPrint('*** DEBUG (R-2) DATABASE FAIL: getProjectSummary failed for ID $projectId: $e ***');
      return null;
    }
  }

  Future<List<ProjectSummaryViewModel>> getProjectListReport({required bool activeOnly}) async {
    final rows = await _db.customSelect(
      'SELECT id FROM projects WHERE is_completed = ?',
      variables: [Variable.withInt(activeOnly ? 0 : 1)],
    ).get();

    final futures = rows.map((r) {
      final projectId = r.data['id'] as int;
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

  Future<List<Map<String, dynamic>>> getCustomProjectReport(CustomReportSettings settings) async {
    List<String> whereConditions = [];
    List<Variable> vars = [];

    if (settings.clientId != null) {
      whereConditions.add('p.client_id = ?');
      vars.add(Variable.withInt(settings.clientId!));
    }
    if (settings.projectId != null) {
      whereConditions.add('p.id = ?');
      vars.add(Variable.withInt(settings.projectId!));
    }

    String dateFilter = '';
    if (settings.startDate != null) {
      dateFilter += ' AND te.start_time >= ?';
      vars.add(Variable.withString(settings.startDate!.toIso8601String()));
    }
    if (settings.endDate != null) {
      dateFilter += ' AND te.start_time <= ?';
      vars.add(Variable.withString(settings.endDate!.toIso8601String()));
    }

    String whereClause = whereConditions.isEmpty ? '1=1' : whereConditions.join(' AND ');

    List<String> selectFields = ['p.project_name AS project'];
    if (settings.includes['Client Details'] == true) selectFields.add('c.name AS client');
    if (settings.includes['Total Hours'] == true) selectFields.add('IFNULL(SUM(te.final_billed_duration_seconds / 3600.0), 0.0) AS total_hours');
    if (settings.includes['Billed Rate'] == true) {
      selectFields.add('p.billed_hourly_rate AS hourly_rate');
      selectFields.add('p.project_price AS project_price');
      selectFields.add('p.pricing_model');
    }
    if (settings.includes['Expense Totals'] == true) {
      selectFields.add('IFNULL((SELECT SUM(cost) FROM materials m WHERE m.project_id = p.id AND m.is_deleted = 0), 0.0) AS total_expenses');
    }

    final query = '''
    SELECT ${selectFields.join(', ')}
    FROM projects p
    LEFT JOIN clients c ON p.client_id = c.id
    LEFT JOIN time_entries te ON p.id = te.project_id $dateFilter
    WHERE $whereClause
    GROUP BY p.id
    ORDER BY p.project_name
  ''';

    final rows = await _db.customSelect(query, variables: vars).get();
    return rows.map((r) => r.data).toList();
  }

  // =========================================================================
  // CRUD & UTILITY METHODS
  // =========================================================================

  Future<List<Project>> getProjects() async {
    final rows = await _db.customSelect('SELECT * FROM projects').get();
    return rows.map((r) => Project.fromMap(r.data)).toList();
  }

  Future<Project?> getProjectById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM projects WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.first.data);
  }

  Future<int> insertProject(Project project) async {
    final id = await _db.customInsert(
      '''INSERT OR REPLACE INTO projects (
        project_name, client_id, location, pricing_model, is_completed,
        completion_date, is_internal, billed_hourly_rate, project_price,
        expense_markup_percentage, tax_rate, parent_project_id,
        street_address, region, postal_code
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString(project.projectName),
        Variable.withInt(project.clientId),
        Variable(project.location),
        Variable.withString(project.pricingModel),
        Variable.withInt(project.isCompleted ? 1 : 0),
        Variable(project.completionDate?.toIso8601String()),
        Variable.withInt(project.isInternal ? 1 : 0),
        Variable(project.billedHourlyRate),
        Variable(project.fixedPrice),
        Variable.withReal(project.expenseMarkupPercentage),
        Variable.withReal(project.taxRate),
        Variable(project.parentProjectId),
        Variable(project.streetAddress),
        Variable(project.region),
        Variable(project.postalCode),
      ],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<int> updateProject(Project project) async {
    final result = await _db.customUpdate(
      '''UPDATE projects SET
        project_name = ?, client_id = ?, location = ?, pricing_model = ?,
        is_completed = ?, completion_date = ?, is_internal = ?,
        billed_hourly_rate = ?, project_price = ?,
        expense_markup_percentage = ?, tax_rate = ?, parent_project_id = ?,
        street_address = ?, region = ?, postal_code = ?
      WHERE id = ?''',
      variables: [
        Variable.withString(project.projectName),
        Variable.withInt(project.clientId),
        Variable(project.location),
        Variable.withString(project.pricingModel),
        Variable.withInt(project.isCompleted ? 1 : 0),
        Variable(project.completionDate?.toIso8601String()),
        Variable.withInt(project.isInternal ? 1 : 0),
        Variable(project.billedHourlyRate),
        Variable(project.fixedPrice),
        Variable.withReal(project.expenseMarkupPercentage),
        Variable.withReal(project.taxRate),
        Variable(project.parentProjectId),
        Variable(project.streetAddress),
        Variable(project.region),
        Variable(project.postalCode),
        Variable.withInt(project.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteProject(int id) async {
    final result = await _db.customUpdate(
      'DELETE FROM projects WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<bool> hasAssociatedRecords(int projectId) async {
    final timeRows = await _db.customSelect(
      'SELECT id FROM time_entries WHERE project_id = ? LIMIT 1',
      variables: [Variable.withInt(projectId)],
    ).get();
    if (timeRows.isNotEmpty) return true;

    final materialRows = await _db.customSelect(
      'SELECT id FROM materials WHERE project_id = ? LIMIT 1',
      variables: [Variable.withInt(projectId)],
    ).get();
    if (materialRows.isNotEmpty) return true;

    return false;
  }
}
