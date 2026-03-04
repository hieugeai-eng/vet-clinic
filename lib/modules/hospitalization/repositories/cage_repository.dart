import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../data/models/cage_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/base_sync_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/sync/sync_engine.dart';
import 'package:get/get.dart';

class CageRepository with SyncCapable {
  final _provider = DatabaseProvider.instance;

  Future<List<CageModel>> getAllCages() async {
    final db = await _provider.database;
    String? where;
    List<dynamic>? args;

    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        where = '(clinic_id = ? OR clinic_id IS NULL)';
        args = [clinicId];
      }
    }

    final result = await db.query(
      'cages',
      where: where,
      whereArgs: args,
      orderBy: 'order_index ASC',
    );
    return result.map((json) => CageModel.fromJson(json)).toList();
  }

  Future<List<CageModel>> getCagesWithOccupancy() async {
    final db = await _provider.database;

    // Clinic Filter
    String activeClause = "h.status = 'active'";
    List<dynamic> args = [];
    String? cageWhere;
    List<dynamic>? cageArgs;

    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        activeClause += " AND (mc.clinic_id = ? OR mc.clinic_id IS NULL)";
        args.add(clinicId);

        cageWhere = '(clinic_id = ? OR clinic_id IS NULL)';
        cageArgs = [clinicId];

        // Auto-patch: assign current clinic_id to cages that have none
        try {
          await db.update('cages', {
            'clinic_id': clinicId,
          }, where: 'clinic_id IS NULL');
        } catch (_) {}
      }
    }

    // 1. Fetch cages
    final cagesResult = await db.query(
      'cages',
      where: cageWhere,
      whereArgs: cageArgs,
      orderBy: 'order_index ASC',
    );
    final cages = cagesResult.map((json) => CageModel.fromJson(json)).toList();

    // 2. Fetch active hospitalizations
    final occupantsResult = await db.rawQuery('''
      SELECT h.*, p.name as pet_name, s.name as staff_name, mc.diagnosis
      FROM hospitalizations h
      JOIN pets p ON h.pet_id = p.id
      JOIN medical_cases mc ON h.case_id = mc.id
      LEFT JOIN staff s ON h.staff_id = s.id
      WHERE $activeClause
    ''', args);

    // 3. Map occupants to cages
    final occupantsMap = <String, List<CageOccupant>>{};
    for (var row in occupantsResult) {
      if (row['cage_id'] == null) continue;

      final cageId = row['cage_id'].toString();
      try {
        // Fetch active treatments for today
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        final hospId = row['id'];

        final treatmentsRes = await db.rawQuery(
          '''
          SELECT t.name 
          FROM hospitalization_treatments t
          JOIN hospitalization_dailies d ON t.daily_id = d.id
          WHERE d.hospitalization_id = ? AND date(d.date) = ? AND t.status = 'pending'
        ''',
          [hospId, todayStr],
        );

        List<String> treatments = treatmentsRes
            .map((t) => t['name'].toString())
            .toList();

        var mutableRow = Map<String, dynamic>.from(row);
        mutableRow['active_treatments'] = treatments;

        final occupant = CageOccupant.fromJson(mutableRow);

        if (!occupantsMap.containsKey(cageId)) {
          occupantsMap[cageId] = [];
        }
        occupantsMap[cageId]!.add(occupant);
      } catch (e) {
        print('Error parsing occupant: $e');
      }
    }

    // 4. Return cages with occupants populated
    return cages.map((cage) {
      final cageOccupants = occupantsMap[cage.id] ?? [];

      String status = cage.status;
      if (cageOccupants.isNotEmpty && status != 'maintenance') {
        status = 'occupied';
      }

      return cage.copyWith(status: status, occupants: cageOccupants);
    }).toList();
  }

  Future<void> addCage(CageModel cage) async {
    var newCage = cage.copyWith();

    if (newCage.clinicId == null && Get.isRegistered<AuthService>()) {
      newCage = newCage.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    await insertWithSync(
      table: 'cages',
      data: newCage.toJson(),
      id: newCage.id,
    );
  }

  Future<void> updateCage(CageModel cage) async {
    var updated = cage.copyWith();

    if (updated.clinicId == null && Get.isRegistered<AuthService>()) {
      updated = updated.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    await updateWithSync(
      table: 'cages',
      recordId: cage.id,
      data: updated.toJson(),
    );
  }

  Future<void> updateCageStatus(String id, String status) async {
    await updateWithSync(
      table: 'cages',
      recordId: id,
      data: {'status': status},
    );
  }

  Future<void> deleteCage(String id) async {
    await deleteWithSync(table: 'cages', recordId: id, softDelete: false);
  }
}
