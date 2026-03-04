import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_rest_client.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../core/services/staff_sync_helper.dart';

class StaffManagementController extends GetxController {
  final staffList = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchStaff();
  }

  Future<void> fetchStaff() async {
    isLoading.value = true;
    try {
      final clinicId = AuthService.to.currentClinic.value?.id;
      if (clinicId == null) {
        Get.snackbar('Lỗi', 'Không tìm thấy phòng khám');
        return;
      }

      // Fetch owner profile from profiles table
      final profiles = await SupabaseRestClient.to.get(
        'profiles',
        query: {
          'clinic_id': 'eq.$clinicId',
          'select':
              'id,full_name,role,avatar_url,pin_hash,specialization,is_active',
        },
      );

      // Fetch additional staff from clinic_staff table
      List<dynamic> clinicStaff = [];
      try {
        clinicStaff = await SupabaseRestClient.to.get(
          'clinic_staff',
          query: {
            'clinic_id': 'eq.$clinicId',
            'select': '*',
            'order': 'role.asc,full_name.asc',
          },
        );
      } catch (e) {
        debugPrint('StaffMgmt: clinic_staff table not found yet: $e');
      }

      // Merge: tag source so we know which table to update
      final merged = <Map<String, dynamic>>[];
      for (final p in profiles) {
        merged.add({...p, '_source': 'profiles'});
      }
      for (final s in clinicStaff) {
        merged.add({...s, '_source': 'clinic_staff'});
      }

      staffList.value = merged;

      // Full sync to local SQLite so all dropdowns use fresh data
      await StaffSyncHelper.forceSync();
    } catch (e) {
      debugPrint('StaffManagement Error: $e');
      Get.snackbar(
        'Lỗi',
        'Không thể tải danh sách nhân viên',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if PIN is unique across all staff (profiles + clinic_staff)
  Future<bool> _isPinUnique(String pin, {String? excludeId}) async {
    final pinHash = sha256.convert(utf8.encode(pin)).toString();

    // Check against current loaded staff list
    for (final s in staffList) {
      if (excludeId != null && s['id'] == excludeId) continue;
      if (s['pin_hash'] == pinHash) {
        final name = s['full_name'] ?? 'Nhân viên';
        Get.snackbar(
          'Mã PIN trùng',
          'Mã PIN này đã được sử dụng bởi "$name". Vui lòng chọn mã khác.',
          backgroundColor: Colors.orange.shade100,
          duration: const Duration(seconds: 3),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> createStaff({
    required String fullName,
    required String role,
    String? specialization,
    String? phone,
    String? email,
    String? pin,
    List<String>? customModules,
  }) async {
    try {
      final clinicId = AuthService.to.currentClinic.value?.id;
      if (clinicId == null) return;

      String? pinHash;
      if (pin != null && pin.length == 4) {
        // Check uniqueness
        if (!await _isPinUnique(pin)) return;
        pinHash = sha256.convert(utf8.encode(pin)).toString();
      }

      final staffId = const Uuid().v4();

      await SupabaseRestClient.to.upsert('clinic_staff', {
        'id': staffId,
        'clinic_id': clinicId,
        'full_name': fullName,
        'role': role,
        'specialization': specialization,
        'pin_hash': pinHash,
        'custom_modules': customModules != null
            ? jsonEncode(customModules)
            : null,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Sync to local staff table (for dropdowns)
      await _syncToLocalStaff(staffId, fullName, role, phone, email, clinicId);

      Get.snackbar(
        'Thành công',
        'Đã thêm nhân viên: $fullName',
        backgroundColor: Colors.green.shade100,
      );
      fetchStaff();
    } catch (e) {
      debugPrint('StaffMgmt createStaff error: $e');
      Get.snackbar(
        'Lỗi',
        'Không thể thêm nhân viên: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> updateStaff(
    Map<String, dynamic> staff, {
    String? fullName,
    String? role,
    String? specialization,
    String? phone,
    String? email,
    String? newPin,
    List<String>? customModules,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (fullName != null) data['full_name'] = fullName;
      if (role != null) data['role'] = role;
      if (specialization != null) data['specialization'] = specialization;
      if (newPin != null && newPin.length == 4) {
        // Check uniqueness (exclude current staff)
        if (!await _isPinUnique(newPin, excludeId: staff['id'])) return;
        data['pin_hash'] = sha256.convert(utf8.encode(newPin)).toString();
      }
      if (customModules != null) {
        data['custom_modules'] = jsonEncode(customModules);
      }

      final table = staff['_source'] == 'profiles'
          ? 'profiles'
          : 'clinic_staff';
      await SupabaseRestClient.to.patch(
        table,
        data,
        query: {'id': 'eq.${staff['id']}'},
      );

      // Sync to local staff table
      final clinicId = AuthService.to.currentClinic.value?.id;
      if (clinicId != null) {
        await _syncToLocalStaff(
          staff['id'],
          fullName ?? staff['full_name'] ?? '',
          role ?? staff['role'] ?? 'assistant',
          phone ?? staff['phone'],
          email ?? staff['email'],
          clinicId,
        );
      }

      Get.snackbar(
        'Thành công',
        'Đã cập nhật: ${fullName ?? staff['full_name']}',
        backgroundColor: Colors.green.shade100,
      );
      fetchStaff();
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể cập nhật: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> deactivateStaff(Map<String, dynamic> staff) async {
    // Can't deactivate profiles (auth user)
    if (staff['_source'] == 'profiles') {
      Get.snackbar(
        'Không thể',
        'Không thể vô hiệu hóa chủ tài khoản',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xóa nhân viên'),
        content: Text('Bạn có chắc muốn vô hiệu hóa ${staff['full_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseRestClient.to.patch(
        'clinic_staff',
        {
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        query: {'id': 'eq.${staff['id']}'},
      );

      Get.snackbar(
        'Thành công',
        'Đã vô hiệu hóa: ${staff['full_name']}',
        backgroundColor: Colors.orange.shade100,
      );
      fetchStaff();
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể vô hiệu hóa: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  /// Sync staff to local SQLite staff table for dropdown usage
  Future<void> _syncToLocalStaff(
    String id,
    String name,
    String role,
    String? phone,
    String? email,
    String clinicId,
  ) async {
    try {
      final db = await DatabaseProvider.instance.database;
      // Map role names to local staff role names
      String localRole = role;
      if (role == 'owner' || role == 'admin') localRole = 'doctor';
      if (role == 'assistant') localRole = 'nurse';

      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO staff (id, name, role, phone, email, is_active, clinic_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)
      ''',
        [
          id,
          name,
          localRole,
          phone,
          email,
          clinicId,
          DateTime.now().toUtc().toIso8601String(),
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
    } catch (e) {
      debugPrint('Sync to local staff error: $e');
    }
  }
}
