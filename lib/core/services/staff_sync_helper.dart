import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../data/providers/local/database_provider.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';
import 'supabase_rest_client.dart';

/// Shared helper to sync staff from Supabase (profiles + clinic_staff) to local SQLite.
class StaffSyncHelper {
  static DateTime? _lastSyncTime;
  static const _syncCooldown = Duration(minutes: 5);

  /// Sync staff from cloud to local SQLite, then return local staff list.
  static Future<List<Map<String, dynamic>>> loadStaffWithSync() async {
    final db = await DatabaseProvider.instance.database;

    // Try sync from cloud
    if (_shouldSync()) {
      try {
        debugPrint('[StaffSync] Starting cloud sync...');
        await _syncFromCloud(db);
        _lastSyncTime = DateTime.now();
        debugPrint('[StaffSync] Cloud sync completed');
      } catch (e, stack) {
        debugPrint('[StaffSync] Cloud sync FAILED: $e');
        debugPrint('[StaffSync] Stack: $stack');
      }
    } else {
      debugPrint(
        '[StaffSync] Skipping sync - shouldSync=false (configured=${SupabaseConfig.isConfigured}, authRegistered=${Get.isRegistered<AuthService>()}, loggedIn=${Get.isRegistered<AuthService>() ? AuthService.to.isLoggedIn.value : "N/A"}, cooldown=${_lastSyncTime != null ? DateTime.now().difference(_lastSyncTime!).inSeconds : "never"}s)',
      );
    }

    // Return from local SQLite - no filter on is_active to see all
    final result = await db.query('staff', orderBy: 'name ASC');
    debugPrint(
      '[StaffSync] Local staff count: ${result.length}, names: ${result.map((r) => r['name']).toList()}',
    );
    return result;
  }

  /// Force sync regardless of cooldown
  static Future<List<Map<String, dynamic>>> forceSync() async {
    final db = await DatabaseProvider.instance.database;
    try {
      debugPrint('[StaffSync] Force sync starting...');
      await _syncFromCloud(db);
      _lastSyncTime = DateTime.now();
    } catch (e, stack) {
      debugPrint('[StaffSync] Force sync FAILED: $e');
      debugPrint('[StaffSync] Stack: $stack');
    }
    final result = await db.query('staff', orderBy: 'name ASC');
    debugPrint('[StaffSync] After force sync - count: ${result.length}');
    return result;
  }

  static bool _shouldSync() {
    if (!SupabaseConfig.isConfigured) return false;
    if (!Get.isRegistered<AuthService>()) return false;
    if (!AuthService.to.isLoggedIn.value) return false;
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _syncCooldown) {
      return false;
    }
    return true;
  }

  static Future<void> _syncFromCloud(dynamic db) async {
    final clinicId = AuthService.to.currentClinic.value?.id;
    debugPrint('[StaffSync] clinicId = $clinicId');
    if (clinicId == null) {
      debugPrint('[StaffSync] ABORT: clinicId is null');
      return;
    }

    // Fetch profiles (match StaffManagementController schema)
    debugPrint('[StaffSync] Fetching profiles...');
    final profiles = await SupabaseRestClient.to.get(
      'profiles',
      query: {
        'clinic_id': 'eq.$clinicId',
        'select': 'id,full_name,role,is_active',
      },
    );
    debugPrint(
      '[StaffSync] Got ${profiles.length} profiles: ${profiles.map((p) => p['full_name']).toList()}',
    );

    // Fetch clinic_staff
    List<dynamic> clinicStaff = [];
    try {
      clinicStaff = await SupabaseRestClient.to.get(
        'clinic_staff',
        query: {'clinic_id': 'eq.$clinicId', 'select': '*'},
      );
      debugPrint(
        '[StaffSync] Got ${clinicStaff.length} clinic_staff: ${clinicStaff.map((s) => s['full_name']).toList()}',
      );
    } catch (e) {
      debugPrint('[StaffSync] clinic_staff fetch error: $e');
    }

    // Wipe ALL old local staff and re-insert from cloud
    final beforeCount = (await db.query('staff')).length;
    await db.delete('staff');
    debugPrint('[StaffSync] Wiped $beforeCount old entries');

    for (final p in profiles) {
      await _insertLocal(db, p, clinicId);
    }
    for (final s in clinicStaff) {
      final existingId = s['id'];
      final existing = await db.query(
        'staff',
        where: 'id = ?',
        whereArgs: [existingId],
      );
      if (existing.isEmpty) {
        await _insertLocal(db, s, clinicId);
      }
    }

    final afterCount = (await db.query('staff')).length;
    debugPrint('[StaffSync] DONE: inserted $afterCount entries');
  }

  static Future<void> _insertLocal(
    dynamic db,
    Map<String, dynamic> data,
    String clinicId,
  ) async {
    String role = (data['role'] ?? 'staff').toString();
    // Keep original role names for display, don't map

    final isActive = data['is_active'];
    final activeInt = (isActive == null || isActive == true || isActive == 1)
        ? 1
        : 0;

    final name = data['full_name'] ?? data['name'] ?? 'Unknown';
    debugPrint('[StaffSync] Inserting: $name (role=$role, active=$activeInt)');

    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO staff (id, name, role, phone, email, is_active, clinic_id, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        data['id'],
        name,
        role,
        data['phone'],
        data['email'],
        activeInt,
        clinicId,
        now,
        now,
      ],
    );
  }
}
