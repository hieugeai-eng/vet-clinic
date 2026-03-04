import 'package:uuid/uuid.dart';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/medicine_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/services/auth_service.dart';
import 'base_sync_repository.dart';

/// Repository for Medicine operations with cloud sync
class MedicineRepository with SyncCapable {
  static const _uuid = Uuid();

  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  Future<List<MedicineModel>> getAll({int? limit, int? offset}) async {
    final results = await queryActive(
      table: 'medicines',
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return results.map((m) => MedicineModel.fromJson(m)).toList();
  }

  Future<MedicineModel?> getById(String id) async {
    final database = await db;
    final results = await database.query(
      'medicines',
      where: 'id = ? AND _is_deleted = 0',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return MedicineModel.fromJson(results.first);
  }

  Future<MedicineModel?> getByCode(String code) async {
    final database = await db;
    final results = await database.query(
      'medicines',
      where: 'code = ? AND _is_deleted = 0',
      whereArgs: [code],
    );
    if (results.isEmpty) return null;
    return MedicineModel.fromJson(results.first);
  }

  Future<List<MedicineModel>> search(String query) async {
    final database = await db;
    String where =
        '(name LIKE ? OR code LIKE ?) AND is_active = 1 AND _is_deleted = 0';
    List<dynamic> args = ['%$query%', '%$query%'];
    final clinicId = currentClinicId;
    if (clinicId != null) {
      where += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.query(
      'medicines',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
      limit: 50,
    );
    return results.map((m) => MedicineModel.fromJson(m)).toList();
  }

  Future<List<MedicineModel>> getLowStock() async {
    final database = await db;
    final clinicId = currentClinicId;
    String clinicFilter = '';
    List<dynamic> args = [];
    if (clinicId != null) {
      clinicFilter = ' AND clinic_id = ?';
      args = [clinicId];
    }
    final results = await database.rawQuery('''
      SELECT * FROM medicines 
      WHERE is_active = 1 AND _is_deleted = 0 AND stock <= COALESCE(min_stock, 10)$clinicFilter
      ORDER BY stock ASC
    ''', args);
    return results.map((m) => MedicineModel.fromJson(m)).toList();
  }

  Future<MedicineModel> create(MedicineModel medicine) async {
    var newMedicine = medicine.copyWith(
      id: medicine.id.isEmpty ? _uuid.v4() : medicine.id,
    );

    if (newMedicine.clinicId == null && Get.isRegistered<AuthService>()) {
      newMedicine = newMedicine.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    final data = newMedicine.toJson();
    await insertWithSync(table: 'medicines', data: data, id: newMedicine.id);

    // Also try immediate push
    if (Get.isRegistered<SyncEngine>()) {
      SyncEngine.to.pushImmediate(table: 'medicines', data: data);
    }

    return newMedicine;
  }

  Future<MedicineModel> update(MedicineModel medicine) async {
    var updated = medicine.copyWith();

    if (updated.clinicId == null && Get.isRegistered<AuthService>()) {
      updated = updated.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    final data = updated.toJson();
    await updateWithSync(table: 'medicines', recordId: medicine.id, data: data);

    // Also try immediate push
    if (Get.isRegistered<SyncEngine>()) {
      SyncEngine.to.pushImmediate(table: 'medicines', data: data);
    }

    return updated;
  }

  Future<void> updateStock(String id, double newStock) async {
    await updateWithSync(
      table: 'medicines',
      recordId: id,
      data: {'stock': newStock},
    );
  }

  Future<void> delete(String id) async {
    await deleteWithSync(table: 'medicines', recordId: id, softDelete: true);
  }

  Future<int> count() async {
    final database = await db;
    final clinicId = currentClinicId;
    String query =
        'SELECT COUNT(*) as count FROM medicines WHERE is_active = 1 AND _is_deleted = 0';
    List<dynamic> args = [];
    if (clinicId != null) {
      query += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final result = await database.rawQuery(query, args);
    return result.first['count'] as int? ?? 0;
  }

  Future<double> getTotalStockValue() async {
    final database = await db;
    final clinicId = currentClinicId;
    String clinicFilter = '';
    List<dynamic> args = [];
    if (clinicId != null) {
      clinicFilter = ' AND clinic_id = ?';
      args = [clinicId];
    }
    final result = await database.rawQuery('''
      SELECT COALESCE(SUM(stock * avg_price), 0) as total 
      FROM medicines WHERE is_active = 1 AND _is_deleted = 0$clinicFilter
    ''', args);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  // Transactions
  Future<List<MedicineTransactionModel>> getTransactions({
    String? medicineId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    final database = await db;
    final where = <String>[];
    final args = <dynamic>[];

    if (medicineId != null) {
      where.add('medicine_id = ?');
      args.add(medicineId);
    }
    if (fromDate != null) {
      where.add('transaction_date >= ?');
      args.add(fromDate.toUtc().toIso8601String());
    }
    if (toDate != null) {
      where.add('transaction_date <= ?');
      args.add(toDate.toUtc().toIso8601String());
    }

    final results = await database.query(
      'medicine_transactions',
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'transaction_date DESC',
      limit: limit,
    );
    return results.map((t) => MedicineTransactionModel.fromJson(t)).toList();
  }

  Future<MedicineTransactionModel> createTransaction(
    MedicineTransactionModel transaction,
  ) async {
    final clinicId =
        transaction.clinicId ??
        (Get.isRegistered<AuthService>()
            ? AuthService.to.currentProfile.value?.clinicId
            : null);

    final newTrans = MedicineTransactionModel(
      id: transaction.id.isEmpty ? _uuid.v4() : transaction.id,
      clinicId: clinicId,
      medicineId: transaction.medicineId,
      type: transaction.type,
      quantity: transaction.quantity,
      unitPrice: transaction.unitPrice,
      caseId: transaction.caseId,
      lotNumber: transaction.lotNumber,
      purpose: transaction.purpose,
      staffId: transaction.staffId,
      notes: transaction.notes,
      transactionDate: transaction.transactionDate,
    );

    await insertWithSync(
      table: 'medicine_transactions',
      data: newTrans.toJson(),
      id: newTrans.id,
    );

    // Update stock
    final medicine = await getById(transaction.medicineId);
    if (medicine != null) {
      double newStock = medicine.stock;
      if (transaction.type == 'import') {
        newStock += transaction.quantity;
      } else {
        newStock -= transaction.quantity;
      }
      await updateStock(medicine.id, newStock);
    }

    return newTrans;
  }

  /// Delete all medicines from local AND cloud
  Future<void> deleteAll() async {
    final database = await db;
    final medicines = await database.query('medicines', columns: ['id']);

    for (final medicine in medicines) {
      await deleteWithSync(
        table: 'medicines',
        recordId: medicine['id'] as String,
        softDelete: true,
      );
    }
  }
}
