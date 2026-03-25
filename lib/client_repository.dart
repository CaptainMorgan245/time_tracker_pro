// lib/client_repository.dart

import 'package:drift/drift.dart';
import 'package:time_tracker_pro/database/app_database.dart';
import 'package:time_tracker_pro/models.dart';

class ClientRepository {
  final _db = AppDatabase.instance;

  Future<int> insertClient(Client client) async {
    final id = await _db.customInsert(
      'INSERT OR REPLACE INTO clients (name, is_active, contact_person, phone_number) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(client.name),
        Variable.withInt(client.isActive ? 1 : 0),
        Variable(client.contactPerson),
        Variable(client.phoneNumber),
      ],
    );
    _db.notifyDatabaseChanged();
    return id;
  }

  Future<List<Client>> getClients() async {
    final rows = await _db.customSelect('SELECT * FROM clients').get();
    return rows.map((r) => Client.fromMap(r.data)).toList();
  }

  Future<Client?> getClientById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM clients WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first.data);
  }

  Future<int> updateClient(Client client) async {
    final result = await _db.customUpdate(
      'UPDATE clients SET name = ?, is_active = ?, contact_person = ?, phone_number = ? WHERE id = ?',
      variables: [
        Variable.withString(client.name),
        Variable.withInt(client.isActive ? 1 : 0),
        Variable(client.contactPerson),
        Variable(client.phoneNumber),
        Variable.withInt(client.id!),
      ],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }

  Future<int> deleteClient(int id) async {
    final result = await _db.customUpdate(
      'DELETE FROM clients WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {},
    );
    _db.notifyDatabaseChanged();
    return result;
  }
}
