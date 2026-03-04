import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/customer_model.dart';
import '../models/pet_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/services/auth_service.dart';
import 'base_sync_repository.dart';

/// Repository for Customer operations with cloud sync
class CustomerRepository with SyncCapable {
  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  Future<List<CustomerModel>> getAll({int? limit, int? offset}) async {
    final results = await queryActive(
      table: 'customers',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((c) => CustomerModel.fromJson(c)).toList();
  }

  Future<CustomerModel?> getById(String id) async {
    final database = await db;
    final results = await database.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return CustomerModel.fromJson(results.first);
  }

  Future<CustomerModel?> getByPhone(String phone) async {
    final database = await db;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final results = await database.query(
      'customers',
      where: 'phone LIKE ?',
      whereArgs: ['%$cleanPhone%'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CustomerModel.fromJson(results.first);
  }

  Future<List<CustomerModel>> search(
    String query, {
    int? limit,
    int? offset,
  }) async {
    final database = await db;
    final clinicId = currentClinicId;
    String where =
        '(_is_deleted IS NULL OR _is_deleted = 0) AND (name LIKE ? OR phone LIKE ? OR address LIKE ?)';
    List<dynamic> args = ['%$query%', '%$query%', '%$query%'];

    if (clinicId != null) {
      where = '$where AND clinic_id = ?';
      args.add(clinicId);
    }

    final results = await database.query(
      'customers',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
      limit: limit ?? 50,
      offset: offset,
    );
    return results.map((c) => CustomerModel.fromJson(c)).toList();
  }

  Future<CustomerModel> create(CustomerModel customer) async {
    final data = customer.toJson();

    // Inject clinic_id
    if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
      data['clinic_id'] = AuthService.to.currentProfile.value?.clinicId;
    }

    final id = await insertWithSync(
      table: 'customers',
      data: data,
      id: customer.id.isEmpty ? null : customer.id,
    );
    return customer.copyWith(id: id);
  }

  Future<CustomerModel> update(CustomerModel customer) async {
    final data = customer.copyWith(updatedAt: DateTime.now()).toJson();

    // Inject clinic_id if missing
    if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
      data['clinic_id'] = AuthService.to.currentProfile.value?.clinicId;
    }

    await updateWithSync(table: 'customers', recordId: customer.id, data: data);
    return customer.copyWith(updatedAt: DateTime.now());
  }

  Future<int> count([String? searchQuery]) async {
    final database = await db;
    final clinicId = currentClinicId;
    String queryStr =
        'SELECT COUNT(*) as count FROM customers WHERE (is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0)';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryStr += ' AND (name LIKE ? OR phone LIKE ? OR address LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    if (clinicId != null) {
      queryStr += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final result = await database.rawQuery(queryStr, args);
    return result.first['count'] as int? ?? 0;
  }

  Future<void> delete(String id) async {
    await deleteWithSync(table: 'customers', recordId: id, softDelete: true);
  }

  Future<List<PetModel>> getCustomerPets(String customerId) async {
    final results = await queryActive(
      table: 'pets',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    return results.map((p) => PetModel.fromJson(p)).toList();
  }

  /// Delete all customers AND their pets
  Future<void> deleteAll() async {
    final database = await db;

    final pets = await database.query('pets', columns: ['id']);
    final customers = await database.query('customers', columns: ['id']);

    for (final pet in pets) {
      await deleteWithSync(table: 'pets', recordId: pet['id'] as String);
    }
    for (final cust in customers) {
      await deleteWithSync(table: 'customers', recordId: cust['id'] as String);
    }
  }
}
