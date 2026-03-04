import 'package:uuid/uuid.dart';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/appointment_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/services/auth_service.dart';
import 'base_sync_repository.dart';

/// Repository for Appointment operations with cloud sync
class AppointmentRepository with SyncCapable {
  static const _uuid = Uuid();

  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  Future<List<AppointmentModel>> getAll({int? limit, int? offset}) async {
    final database = await db;
    final clinicId = currentClinicId;
    String clinicFilter = 'WHERE a._is_deleted = 0';
    List<dynamic> args = [];
    if (clinicId != null) {
      clinicFilter = 'WHERE a.clinic_id = ? AND a._is_deleted = 0';
      args = [clinicId];
    }
    final results = await database.rawQuery('''
      SELECT a.*, c.name as customer_name, c.phone as customer_phone, p.name as pet_name
      FROM appointments a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN pets p ON a.pet_id = p.id
      $clinicFilter
      ORDER BY a.appointment_date DESC
      ${limit != null ? 'LIMIT $limit' : ''}
      ${offset != null ? 'OFFSET $offset' : ''}
    ''', args);
    return results.map((a) => AppointmentModel.fromJson(a)).toList();
  }

  Future<AppointmentModel?> getById(String id) async {
    final database = await db;
    final results = await database.rawQuery(
      '''
      SELECT a.*, c.name as customer_name, c.phone as customer_phone, p.name as pet_name
      FROM appointments a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN pets p ON a.pet_id = p.id
      WHERE a.id = ? AND a._is_deleted = 0
    ''',
      [id],
    );
    if (results.isEmpty) return null;
    return AppointmentModel.fromJson(results.first);
  }

  Future<List<AppointmentModel>> getByDate(DateTime date) async {
    final database = await db;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final clinicId = currentClinicId;
    String clinicFilter = '';
    List<dynamic> args = [
      startOfDay.toUtc().toIso8601String(),
      endOfDay.toUtc().toIso8601String(),
    ];
    if (clinicId != null) {
      clinicFilter = 'AND a.clinic_id = ?';
      args.add(clinicId);
    }

    final results = await database.rawQuery('''
      SELECT a.*, c.name as customer_name, c.phone as customer_phone, p.name as pet_name
      FROM appointments a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN pets p ON a.pet_id = p.id
      WHERE a.appointment_date >= ? AND a.appointment_date < ? AND a._is_deleted = 0
      $clinicFilter
      ORDER BY a.time ASC
    ''', args);
    return results.map((a) => AppointmentModel.fromJson(a)).toList();
  }

  Future<List<AppointmentModel>> getUpcoming({int? limit}) async {
    final database = await db;
    final now = DateTime.now();
    final clinicId = currentClinicId;
    String clinicFilter = '';
    List<dynamic> args = [now.toUtc().toIso8601String()];
    if (clinicId != null) {
      clinicFilter = 'AND a.clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.rawQuery('''
      SELECT a.*, c.name as customer_name, c.phone as customer_phone, p.name as pet_name
      FROM appointments a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN pets p ON a.pet_id = p.id
      WHERE a.appointment_date >= ? AND a.status IN ('pending', 'confirmed') AND a._is_deleted = 0
      $clinicFilter
      ORDER BY a.appointment_date ASC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', args);
    return results.map((a) => AppointmentModel.fromJson(a)).toList();
  }

  Future<List<AppointmentModel>> getByDateRange({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final database = await db;
    final clinicId = currentClinicId;
    String clinicFilter = '';
    List<dynamic> args = [
      fromDate.toUtc().toIso8601String(),
      toDate.toUtc().toIso8601String(),
    ];
    if (clinicId != null) {
      clinicFilter = 'AND a.clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.rawQuery('''
      SELECT a.*, c.name as customer_name, c.phone as customer_phone, p.name as pet_name
      FROM appointments a
      LEFT JOIN customers c ON a.customer_id = c.id
      LEFT JOIN pets p ON a.pet_id = p.id
      WHERE a.appointment_date >= ? AND a.appointment_date <= ? AND a._is_deleted = 0
      $clinicFilter
      ORDER BY a.appointment_date ASC, a.time ASC
    ''', args);
    return results.map((a) => AppointmentModel.fromJson(a)).toList();
  }

  Future<AppointmentModel> create(AppointmentModel appointment) async {
    var newAppointment = appointment.copyWith(
      id: appointment.id.isEmpty ? _uuid.v4() : appointment.id,
    );

    if (newAppointment.clinicId == null && Get.isRegistered<AuthService>()) {
      newAppointment = newAppointment.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    final data = newAppointment.toJson();
    await insertWithSync(
      table: 'appointments',
      data: data,
      id: newAppointment.id,
    );

    // Also try immediate push
    if (Get.isRegistered<SyncEngine>()) {
      SyncEngine.to.pushImmediate(table: 'appointments', data: data);
    }

    return newAppointment;
  }

  Future<AppointmentModel> update(AppointmentModel appointment) async {
    var updated = appointment.copyWith();

    if (updated.clinicId == null && Get.isRegistered<AuthService>()) {
      updated = updated.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    final data = updated.toJson();
    await updateWithSync(
      table: 'appointments',
      recordId: appointment.id,
      data: data,
    );

    // Also try immediate push
    if (Get.isRegistered<SyncEngine>()) {
      SyncEngine.to.pushImmediate(table: 'appointments', data: data);
    }

    return updated;
  }

  Future<void> updateStatus(String id, String status) async {
    await updateWithSync(
      table: 'appointments',
      recordId: id,
      data: {'status': status},
    );
  }

  Future<void> delete(String id) async {
    await deleteWithSync(table: 'appointments', recordId: id, softDelete: true);
  }

  Future<int> countToday() async {
    final database = await db;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final clinicId = currentClinicId;
    String clinicFilter = '';
    List<dynamic> args = [
      startOfDay.toUtc().toIso8601String(),
      endOfDay.toUtc().toIso8601String(),
    ];
    if (clinicId != null) {
      clinicFilter = 'AND clinic_id = ?';
      args.add(clinicId);
    }

    final result = await database.rawQuery('''
      SELECT COUNT(*) as count FROM appointments
      WHERE appointment_date >= ? AND appointment_date < ?
      AND status IN ('pending', 'confirmed') AND _is_deleted = 0
      $clinicFilter
    ''', args);
    return result.first['count'] as int? ?? 0;
  }
}
