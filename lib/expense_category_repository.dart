import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class ExpenseCategoryRepository {
  final _db = AppDatabase.instance;

  Future<int> insertExpenseCategory(ExpenseCategory category) async {
    final id = await _db.customInsert(
      'INSERT OR REPLACE INTO expense_categories (name) VALUES (?)',
      variables: [Variable.withString(category.name)],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final rows = await _db.customSelect('SELECT * FROM expense_categories').get();
    return rows.map((r) => ExpenseCategory.fromMap(r.data)).toList();
  }

  Future<ExpenseCategory?> getExpenseCategoryById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM expense_categories WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return ExpenseCategory.fromMap(rows.first.data);
  }

  Future<int> updateExpenseCategory(ExpenseCategory category) async {
    final result = await _db.customUpdate(
      'UPDATE expense_categories SET name = ? WHERE id = ?',
      variables: [
        Variable.withString(category.name),
        Variable.withInt(category.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteExpenseCategory(int id) async {
    final result = await _db.customUpdate(
      'DELETE FROM expense_categories WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
