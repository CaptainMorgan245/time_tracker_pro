// lib/dropdown_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';

// A simple model for dropdown items
class DropdownItem {
  final int id;
  final String name;

  DropdownItem({required this.id, required this.name});
}

class DropdownRepository {
  final dbHelper = DatabaseHelperV2.instance;

  Future<List<DropdownItem>> getClients() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'is_active = 1',
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) {
      return DropdownItem(
        id: maps[i]['id'],
        name: maps[i]['name'],
      );
    });
  }

  Future<List<DropdownItem>> getProjects({int? clientId}) async {
    final db = await dbHelper.database;
    String? whereClause = 'is_completed = 0';
    List<dynamic>? whereArgs = [];

    if (clientId != null) {
      whereClause += ' AND client_id = ?';
      whereArgs.add(clientId);
    }

    if (whereArgs.isEmpty) {
      whereArgs = null;
    }


    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'project_name',
    );

    return List.generate(maps.length, (i) {
      return DropdownItem(
        id: maps[i]['id'],
        name: maps[i]['project_name'],
      );
    });
  }
}
