import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../core/services/auth_service.dart';

class HospitalizationRepository {
  final _provider = DatabaseProvider.instance;

  /// Returns pending treatments past their scheduled time for active hospitalizations TODAY.
  Future<List<Map<String, dynamic>>> getOverdueTreatments() async {
    final db = await _provider.database;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Clinic Filter
    String clinicClause = "";
    List<dynamic> args = [today, nowTime];

    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        clinicClause = " AND mc.clinic_id = ?";
        args.add(clinicId);
      }
    }

    final result = await db.rawQuery('''
      SELECT 
        h.cage_id,
        p.name as pet_name,
        ht.name as treatment_name,
        ht.time_scheduled
      FROM hospitalization_treatments ht
      JOIN hospitalization_dailies hd ON ht.daily_id = hd.id
      JOIN hospitalizations h ON hd.hospitalization_id = h.id
      JOIN medical_cases mc ON h.case_id = mc.id
      JOIN pets p ON h.pet_id = p.id
      WHERE ht.status = 'pending' 
        AND hd.date = ?
        AND ht.time_scheduled < ?
        AND h.status = 'active'
        $clinicClause
      ORDER BY ht.time_scheduled ASC
    ''', args);

    return result;
  }

  /// Returns critical vital signs logged TODAY for active patients.
  /// Feature 12: Extended alerts — checks temp, HR, RR, and CRT
  Future<List<Map<String, dynamic>>> getCriticalVitals() async {
    final db = await _provider.database;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Clinic Filter
    String clinicClause = "";
    List<dynamic> args = [today];

    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        clinicClause = " AND mc.clinic_id = ?";
        args.add(clinicId);
      }
    }

    // Extended checks: Temp > 40 or < 36, HR > 180, RR > 40, CRT abnormal
    final result = await db.rawQuery('''
      SELECT 
        h.cage_id,
        p.name as pet_name,
        v.temperature,
        v.heart_rate,
        v.respiratory_rate,
        v.crt,
        v.time,
        v.created_at
      FROM vital_sign_logs v
      JOIN hospitalization_dailies hd ON v.daily_id = hd.id
      JOIN hospitalizations h ON hd.hospitalization_id = h.id
      JOIN medical_cases mc ON h.case_id = mc.id
      JOIN pets p ON h.pet_id = p.id
      WHERE hd.date = ?
        AND (
          v.temperature > 40 OR v.temperature < 36 
          OR v.heart_rate > 180 
          OR v.respiratory_rate > 40
        )
        AND h.status = 'active'
        $clinicClause
      ORDER BY v.created_at DESC
    ''', args);

    return result;
  }
}
