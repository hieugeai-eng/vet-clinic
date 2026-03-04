import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/supabase_rest_client.dart';
import '../../../../data/models/clinic_device_model.dart'; // Ensure this model exists or use Map

class DeviceManagementController extends GetxController {
  final pendingDevices = <Map<String, dynamic>>[].obs;
  final approvedDevices = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    isLoading.value = true;
    try {
      final clinicId = AuthService.to.currentClinic.value?.id;
      if (clinicId == null) return;

      final data = await SupabaseRestClient.to.get(
        'clinic_devices',
        query: {'clinic_id': 'eq.$clinicId'},
      );

      pendingDevices.value = List<Map<String, dynamic>>.from(
        data.where((d) => d['is_approved'] == 0 || d['is_approved'] == false),
      );
      approvedDevices.value = List<Map<String, dynamic>>.from(
        data.where((d) => d['is_approved'] == 1 || d['is_approved'] == true),
      );
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('404')) {
        Get.snackbar(
          'Cấu hình',
          'Bảng clinic_devices chưa được tạo trên Supabase. Vui lòng chạy migration.',
          backgroundColor: Colors.orange.shade100,
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar('Error', 'Failed to load devices: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approveDevice(String id) async {
    try {
      await SupabaseRestClient.to.patch(
        'clinic_devices',
        {'is_approved': 1},
        query: {'id': 'eq.$id'},
      );
      Get.snackbar(
        'Thành công',
        'Đã phê duyệt thiết bị',
        backgroundColor: Colors.green.shade100,
      );
      fetchDevices();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể phê duyệt: $e');
    }
  }

  Future<void> removeDevice(String id) async {
    try {
      await SupabaseRestClient.to.delete(
        'clinic_devices',
        query: {'id': 'eq.$id'},
      );
      Get.snackbar(
        'Thành công',
        'Đã xóa thiết bị',
        backgroundColor: Colors.green.shade100,
      );
      fetchDevices();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa: $e');
    }
  }
}
