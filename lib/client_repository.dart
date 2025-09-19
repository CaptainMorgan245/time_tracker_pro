// lib/client_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';

class ClientRepository {
  final _databaseHelper = DatabaseHelper();

  // start method: insertClient
  Future<int> insertClient(Client client) async {
    final db = await _databaseHelper.database;
    return await db.insert('clients', client.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // end method: insertClient

  // start method: getClients
  Future<List<Client>> getClients() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('clients');
    return List.generate(maps.length, (i) {
      return Client.fromMap(maps[i]);
    });
  }
  // end method: getClients

  // start method: getClientById
  Future<Client?> getClientById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Client.fromMap(maps.first);
    }
    return null;
  }
  // end method: getClientById

  // start method: updateClient
  Future<int> updateClient(Client client) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }
  // end method: updateClient

  // start method: deleteClient
  Future<int> deleteClient(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// end method: deleteClient
}