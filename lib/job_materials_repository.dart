// lib/job_materials_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:flutter/foundation.dart';

class JobMaterialsRepository {
  final _databaseHelper = DatabaseHelperV2.instance;
  final String _tableName = 'materials'; // Confirmed table name from database_helper

  // start method: insertJobMaterial
  Future<int> insertJobMaterial(JobMaterials material) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      _tableName,
      material.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // end method: insertJobMaterial

  // start method: getJobMaterials
  // Updated to accept an optional 'limit' for fetching recent records
  Future<List<JobMaterials>> getJobMaterials({int? limit}) async {
    final db = await _databaseHelper.database;

    // FIX: Pass the limit directly as an int?, removing unnecessary String conversion
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'id DESC', // Assumes higher ID means more recent
      limit: limit, // Now passing int? directly
    );

    return List.generate(maps.length, (i) {
      return JobMaterials.fromMap(maps[i]);
    });
  }
  // end method: getJobMaterials

  // start method: getJobMaterialsByProjectId
  Future<List<JobMaterials>> getJobMaterialsByProjectId(int projectId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'purchase_date DESC',
    );
    return List.generate(maps.length, (i) {
      return JobMaterials.fromMap(maps[i]);
    });
  }
  // end method: getJobMaterialsByProjectId

  // start method: updateJobMaterial
  Future<int> updateJobMaterial(JobMaterials material) async {
    final db = await _databaseHelper.database;
    return await db.update(
      _tableName,
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }
  // end method: updateJobMaterial

  // start method: getAllJobMaterials
  Future<List<JobMaterials>> getAllJobMaterials() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'id DESC',
    );
    print('DATABASE DEBUG: Fetched ${maps.length} records from the database.');
    return List.generate(maps.length, (i) {
      return JobMaterials.fromMap(maps[i]);
    });
  }
  // end method: getAllJobMaterials

  // start method: getCostSummaryByCategory

  Future<List<CostSummary>> getCostSummaryByCategory() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        expense_category AS categoryName,
        SUM(cost) AS totalCost,
        COUNT(id) AS recordCount
      FROM $_tableName
      GROUP BY expense_category
      HAVING totalCost IS NOT NULL AND totalCost > 0
    ''');

    return List.generate(maps.length, (i) {
      // NOTE: We rely on the SQL query aliases (categoryName, totalCost, recordCount)
      // matching the fields required by the CostSummary model constructor.
      return CostSummary(
        categoryName: maps[i]['categoryName'] as String,
        totalCost: (maps[i]['totalCost'] as num).toDouble(),
        recordCount: maps[i]['recordCount'] as int,
      );
    });
  }
  // end method: getCostSummaryByCategory

  // Fetch company overhead expenses with optional date filtering
  Future<List<Map<String, dynamic>>> getCompanyExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseHelper.database;

    List<String> whereConditions = ['is_company_expense = 1', 'is_deleted = 0'];
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereConditions.add('purchase_date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereConditions.add('purchase_date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    String whereClause = whereConditions.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'purchase_date DESC',
    );

    // Return formatted data for display
    debugPrint('[CompanyExpenses] Found ${maps.length} company expenses');
    return maps.map((map) {
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

  // end method: getCompanyExpenses


  // start method: deleteJobMaterial
  Future<int> deleteJobMaterial(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteJobMaterial
}
