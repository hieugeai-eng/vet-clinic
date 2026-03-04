import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/models/hospitalization_models.dart';
import '../../../data/repositories/base_sync_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/sync/sync_engine.dart';
import 'package:get/get.dart';

class ReservationRepository with SyncCapable {
  final _provider = DatabaseProvider.instance;

  Future<List<ReservationModel>> getReservationsByCage(String cageId) async {
    final db = await _provider.database;

    final result = await db.query(
      'hospitalization_reservations',
      where: 'cage_id = ? AND status != ? AND end_date >= ?',
      whereArgs: [
        cageId,
        'cancelled',
        DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
      ],
      orderBy: 'start_date ASC',
    );

    return result.map((json) => ReservationModel.fromJson(json)).toList();
  }

  Future<bool> checkAvailability(
    String cageId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _provider.database;

    final result = await db.query(
      'hospitalization_reservations',
      where: '''
        cage_id = ? 
        AND status != 'cancelled'
        AND start_date < ? 
        AND end_date > ?
      ''',
      whereArgs: [
        cageId,
        end.toUtc().toIso8601String(),
        start.toUtc().toIso8601String(),
      ],
    );

    return result.isEmpty;
  }

  Future<void> createReservation(ReservationModel reservation) async {
    var newRes = reservation;

    if (newRes.clinicId == null && Get.isRegistered<AuthService>()) {
      newRes = ReservationModel(
        id: newRes.id,
        clinicId: AuthService.to.currentProfile.value?.clinicId,
        cageId: newRes.cageId,
        petId: newRes.petId,
        customerId: newRes.customerId,
        startDate: newRes.startDate,
        endDate: newRes.endDate,
        note: newRes.note,
        status: newRes.status,
        createdAt: newRes.createdAt,
        updatedAt: newRes.updatedAt,
      );
    }

    await insertWithSync(
      table: 'hospitalization_reservations',
      data: newRes.toJson(),
      id: newRes.id,
    );
  }

  Future<void> updateStatus(String id, String status) async {
    await updateWithSync(
      table: 'hospitalization_reservations',
      recordId: id,
      data: {'status': status},
    );
  }
}
