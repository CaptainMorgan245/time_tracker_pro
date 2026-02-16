// lib/phase_repository.dart`

import 'package:sqflite/sqflite.dart';
import 'models.dart';

class PhaseRepository {
  final Database db;

  PhaseRepository(this.db);

  // Get all phases
  Future<List<Phase>> getAllPhases() async {
    final List<Map<String, dynamic>> maps = await db.query('phases');
    return List.generate(maps.length, (i) => Phase.fromMap(maps[i]));
  }

  // Get phase by ID
  Future<Phase?> getPhaseById(int id) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'phases',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Phase.fromMap(maps.first);
  }

  // Insert new phase
  Future<int> insertPhase(Phase phase) async {
    return await db.insert('phases', phase.toMap());
  }

  // Update existing phase
  Future<int> updatePhase(Phase phase) async {
    return await db.update(
      'phases',
      phase.toMap(),
      where: 'id = ?',
      whereArgs: [phase.id],
    );
  }

  // Delete phase
  Future<int> deletePhase(int id) async {
    return await db.delete(
      'phases',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}