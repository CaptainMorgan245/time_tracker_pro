// lib/job_materials_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:flutter/foundation.dart';

class JobMaterialsRepository {
  final _db = AppDatabase.instance;

  Future<int> insertJobMaterial(JobMaterials material) async {
    final id = await _db.customInsert(
      '''INSERT OR REPLACE INTO materials (
        project_id, item_name, cost, purchase_date, description, is_deleted,
        expense_category, unit, quantity, base_quantity, odometer_reading,
        is_company_expense, vehicle_designation, vendor_or_subtrade, cost_code_id,
        is_billed, invoice_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withInt(material.projectId),
        Variable.withString(material.itemName),
        Variable.withReal(material.cost),
        Variable.withString(material.purchaseDate.toIso8601String()),
        Variable(material.description),
        Variable.withInt(material.isDeleted ? 1 : 0),
        Variable(material.expenseCategory),
        Variable(material.unit),
        Variable(material.quantity),
        Variable(material.baseQuantity),
        Variable(material.odometerReading),
        Variable.withInt(material.isCompanyExpense ? 1 : 0),
        Variable(material.vehicleDesignation),
        Variable(material.vendorOrSubtrade),
        Variable(material.costCodeId),
        Variable.withInt(material.isBilled ? 1 : 0),
        Variable(material.invoiceId),
      ],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<List<JobMaterials>> getJobMaterials({int? limit}) async {
    String query = 'SELECT * FROM materials ORDER BY id DESC';
    if (limit != null) query += ' LIMIT $limit';
    final rows = await _db.customSelect(query).get();
    return rows.map((r) => JobMaterials.fromMap(r.data)).toList();
  }

  Future<List<JobMaterials>> getJobMaterialsByProjectId(int projectId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM materials WHERE project_id = ? ORDER BY purchase_date DESC',
      variables: [Variable.withInt(projectId)],
    ).get();
    return rows.map((r) => JobMaterials.fromMap(r.data)).toList();
  }

  Future<int> updateJobMaterial(JobMaterials material) async {
    final result = await _db.customUpdate(
      '''UPDATE materials SET
        project_id = ?, item_name = ?, cost = ?, purchase_date = ?, description = ?,
        is_deleted = ?, expense_category = ?, unit = ?, quantity = ?,
        base_quantity = ?, odometer_reading = ?, is_company_expense = ?,
        vehicle_designation = ?, vendor_or_subtrade = ?, cost_code_id = ?,
        is_billed = ?, invoice_id = ?
      WHERE id = ?''',
      variables: [
        Variable.withInt(material.projectId),
        Variable.withString(material.itemName),
        Variable.withReal(material.cost),
        Variable.withString(material.purchaseDate.toIso8601String()),
        Variable(material.description),
        Variable.withInt(material.isDeleted ? 1 : 0),
        Variable(material.expenseCategory),
        Variable(material.unit),
        Variable(material.quantity),
        Variable(material.baseQuantity),
        Variable(material.odometerReading),
        Variable.withInt(material.isCompanyExpense ? 1 : 0),
        Variable(material.vehicleDesignation),
        Variable(material.vendorOrSubtrade),
        Variable(material.costCodeId),
        Variable.withInt(material.isBilled ? 1 : 0),
        Variable(material.invoiceId),
        Variable.withInt(material.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<List<JobMaterials>> getAllJobMaterials() async {
    final rows = await _db.customSelect('SELECT * FROM materials ORDER BY id DESC').get();
    return rows.map((r) => JobMaterials.fromMap(r.data)).toList();
  }

  Future<List<CostSummary>> getCostSummaryByCategory() async {
    final rows = await _db.customSelect('''
      SELECT
        expense_category AS categoryName,
        SUM(cost) AS totalCost,
        COUNT(id) AS recordCount
      FROM materials
      GROUP BY expense_category
      HAVING totalCost IS NOT NULL AND totalCost > 0
    ''').get();

    return rows.map((r) {
      final map = r.data;
      return CostSummary(
        categoryName: map['categoryName'] as String,
        totalCost: (map['totalCost'] as num).toDouble(),
        recordCount: map['recordCount'] as int,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getCompanyExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<String> whereConditions = ['is_company_expense = 1', 'is_deleted = 0'];
    List<Variable> vars = [];

    if (startDate != null) {
      whereConditions.add('purchase_date >= ?');
      vars.add(Variable.withString(startDate.toIso8601String()));
    }

    if (endDate != null) {
      whereConditions.add('purchase_date <= ?');
      vars.add(Variable.withString(endDate.toIso8601String()));
    }

    String whereClause = whereConditions.join(' AND ');
    final rows = await _db.customSelect(
      'SELECT * FROM materials WHERE $whereClause ORDER BY purchase_date DESC',
      variables: vars,
    ).get();

    return rows.map((r) {
      final map = r.data;
      return {
        'Date': map['purchase_date'],
        'Item': map['item_name'],
        'Category': map['expense_category'] ?? 'Uncategorized',
        'Vendor': map['vendor_or_subtrade'] ?? 'N/A',
        'Cost': (map['cost'] as num).toDouble(),
        'Description': map['description'] ?? '',
      };
    }).toList();
  }

  Future<int> deleteJobMaterial(int id) async {
    final result = await _db.customUpdate(
      'DELETE FROM materials WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
