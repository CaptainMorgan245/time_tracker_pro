import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class ExpenseCategoryRepository {
  // Corrected to use the singleton instance
  final _databaseHelper = DatabaseHelper.instance;

  // start method: insertExpenseCategory
  Future<int> insertExpenseCategory(ExpenseCategory category) async {
    final db = await _databaseHelper.database;
    return await db.insert('expense_categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // end method: insertExpenseCategory

  // start method: getExpenseCategories
  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('expense_categories');
    return List.generate(maps.length, (i) {
      return ExpenseCategory.fromMap(maps[i]);
    });
  }
  // end method: getExpenseCategories

  // start method: getExpenseCategoryById
  Future<ExpenseCategory?> getExpenseCategoryById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expense_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ExpenseCategory.fromMap(maps.first);
    }
    return null;
  }
  // end method: getExpenseCategoryById

  // start method: updateExpenseCategory
  Future<int> updateExpenseCategory(ExpenseCategory category) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'expense_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }
  // end method: updateExpenseCategory

  // start method: deleteExpenseCategory
  Future<int> deleteExpenseCategory(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'expense_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteExpenseCategory
}