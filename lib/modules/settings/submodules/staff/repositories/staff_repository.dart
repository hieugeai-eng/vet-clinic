import '../../../../../data/models/staff_model.dart';
import '../../../../../data/providers/local/database_provider.dart';
import '../../../../../data/repositories/base_sync_repository.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/sync/sync_engine.dart';
import 'package:get/get.dart';

class StaffRepository with SyncCapable {
  String? get _clinicId {
    if (Get.isRegistered<AuthService>()) {
      return AuthService.to.currentProfile.value?.clinicId;
    }
    return null;
  }

  Future<List<StaffModel>> getAllStaff() async {
    final database = await db;
    String? where;
    List<dynamic>? args;
    final clinicId = _clinicId;
    if (clinicId != null) {
      where = 'clinic_id = ? AND (_is_deleted = 0 OR _is_deleted IS NULL)';
      args = [clinicId];
    } else {
      where = '_is_deleted = 0 OR _is_deleted IS NULL';
    }
    final results = await database.query(
      'staff',
      where: where,
      whereArgs: args,
      orderBy: 'name',
    );
    return results.map((e) => StaffModel.fromJson(e)).toList();
  }

  Future<List<StaffModel>> getActiveStaff() async {
    final database = await db;
    String where = 'is_active = 1 AND (_is_deleted = 0 OR _is_deleted IS NULL)';
    List<dynamic> args = [];
    final clinicId = _clinicId;
    if (clinicId != null) {
      where += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.query(
      'staff',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'name',
    );
    return results.map((e) => StaffModel.fromJson(e)).toList();
  }

  Future<void> addStaff(StaffModel staff) async {
    final data = staff.toJson();
    // Inject clinic_id
    final clinicId = _clinicId;
    if (clinicId != null && data['clinic_id'] == null) {
      data['clinic_id'] = clinicId;
    }
    await insertWithSync(table: 'staff', data: data, id: staff.id);
  }

  Future<void> updateStaff(StaffModel staff) async {
    final data = staff.toJson();
    // Inject clinic_id if missing
    final clinicId = _clinicId;
    if (clinicId != null && data['clinic_id'] == null) {
      data['clinic_id'] = clinicId;
    }
    await updateWithSync(table: 'staff', recordId: staff.id, data: data);
  }

  Future<void> deleteStaff(String id) async {
    await deleteWithSync(table: 'staff', recordId: id, softDelete: true);
  }
}
