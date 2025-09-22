// lib/database_initializer.dart

import 'package:time_tracker_pro/database_helper.dart';
import 'package:time_tracker_pro/models.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseInitializer {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // start method: insertInitialData
  Future<void> insertInitialData(Database db) async {
    // Insert initial clients
    final client1 = Client(name: 'Client A');
    final client2 = Client(name: 'Client B');
    final client3 = Client(name: 'Client C');

    final clientId1 = await db.insert('clients', client1.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final clientId2 = await db.insert('clients', client2.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final clientId3 = await db.insert('clients', client3.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Insert initial projects
    final project1 = Project(projectName: 'Project Alpha', clientId: clientId1, pricingModel: 'fixed_price', isInternal: false);
    final project2 = Project(projectName: 'Internal Project', clientId: clientId2, pricingModel: 'hourly', isInternal: true);
    final project3 = Project(projectName: 'Project Gamma', clientId: clientId3, pricingModel: 'hourly', isInternal: false);

    await db.insert('projects', project1.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('projects', project2.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('projects', project3.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Insert initial employees
    final employee1 = Employee(name: 'John Doe', employeeNumber: 'E-001');
    final employee2 = Employee(name: 'Jane Smith', employeeNumber: 'E-002');
    final employee3 = Employee(name: 'Peter Jones', employeeNumber: 'E-003');

    await db.insert('employees', employee1.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('employees', employee2.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('employees', employee3.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
// end method: insertInitialData
}