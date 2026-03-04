import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/pet_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/services/auth_service.dart';
import 'base_sync_repository.dart';

/// Repository for Pet operations with cloud sync
class PetRepository with SyncCapable {
  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  Future<List<PetModel>> getAll({int? limit, int? offset}) async {
    final results = await queryActive(
      table: 'pets',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((p) => PetModel.fromJson(p)).toList();
  }

  Future<PetModel?> getById(String id) async {
    final database = await db;
    final results = await database.query(
      'pets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return PetModel.fromJson(results.first);
  }

  Future<List<PetModel>> getByCustomerId(String customerId) async {
    final database = await db;
    final results = await database.query(
      'pets',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'name ASC',
    );
    return results.map((p) => PetModel.fromJson(p)).toList();
  }

  Future<List<PetModel>> search(String query, {int? limit, int? offset}) async {
    final database = await db;
    String where =
        '(_is_deleted IS NULL OR _is_deleted = 0) AND (name LIKE ? OR species LIKE ? OR breed LIKE ?)';
    List<dynamic> args = ['%$query%', '%$query%', '%$query%'];

    final clinicId = currentClinicId;
    if (clinicId != null) {
      where = '$where AND clinic_id = ?';
      args.add(clinicId);
    }

    final results = await database.query(
      'pets',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
      limit: limit ?? 50,
      offset: offset,
    );
    return results.map((p) => PetModel.fromJson(p)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllWithCustomer({int? limit}) async {
    final database = await db;
    final clinicId = currentClinicId;
    String whereClause = '';
    List<dynamic> args = [];
    if (clinicId != null) {
      whereClause = 'WHERE p.clinic_id = ?';
      args = [clinicId];
    }
    final results = await database.rawQuery('''
      SELECT p.*, c.name as customer_name, c.phone as customer_phone
      FROM pets p
      LEFT JOIN customers c ON p.customer_id = c.id
      $whereClause
      ORDER BY p.created_at DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', args);
    return results;
  }

  Future<PetModel> create(PetModel pet) async {
    final data = pet.toJson();

    // Inject clinic_id
    if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
      data['clinic_id'] = AuthService.to.currentProfile.value?.clinicId;
    }

    final id = await insertWithSync(
      table: 'pets',
      data: data,
      id: pet.id.isEmpty ? null : pet.id,
    );
    return pet.copyWith(id: id);
  }

  Future<PetModel> update(PetModel pet) async {
    final data = pet.copyWith(updatedAt: DateTime.now()).toJson();

    // Inject clinic_id if missing
    if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
      data['clinic_id'] = AuthService.to.currentProfile.value?.clinicId;
    }

    await updateWithSync(table: 'pets', recordId: pet.id, data: data);
    return pet.copyWith(updatedAt: DateTime.now());
  }

  Future<void> delete(String id) async {
    await deleteWithSync(table: 'pets', recordId: id, softDelete: true);
  }

  Future<int> count([String? searchQuery]) async {
    final database = await db;
    final clinicId = currentClinicId;
    String queryStr =
        'SELECT COUNT(*) as count FROM pets WHERE (_is_deleted IS NULL OR _is_deleted = 0)';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryStr += ' AND (name LIKE ? OR species LIKE ? OR breed LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    if (clinicId != null) {
      queryStr += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final result = await database.rawQuery(queryStr, args);
    return result.first['count'] as int? ?? 0;
  }

  Future<Map<String, int>> countBySpecies() async {
    final database = await db;
    final clinicId = currentClinicId;
    String where = '';
    List<dynamic> args = [];
    if (clinicId != null) {
      where = 'WHERE clinic_id = ?';
      args = [clinicId];
    }
    final results = await database.rawQuery('''
      SELECT species, COUNT(*) as count 
      FROM pets 
      $where
      GROUP BY species 
      ORDER BY count DESC
    ''', args);
    return {for (final r in results) r['species'] as String: r['count'] as int};
  }
}
