import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/global_settings_service.dart';
import '../../../services/excel_service.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/models/service_model.dart';

class SettingsController extends GetxController {
  final clinicNameController = TextEditingController();
  final clinicPhoneController = TextEditingController();
  final clinicAddressController = TextEditingController();
  final clinicLogoPath = RxnString();

  // Zalo
  final zaloAppIdController = TextEditingController();
  final zaloSecretKeyController = TextEditingController();
  final zaloOaIdController = TextEditingController();
  final zaloRefreshTokenController = TextEditingController();

  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    clinicNameController.dispose();
    clinicPhoneController.dispose();
    clinicAddressController.dispose();
    zaloAppIdController.dispose();
    zaloSecretKeyController.dispose();
    zaloOaIdController.dispose();
    zaloRefreshTokenController.dispose();
    super.onClose();
  }

  void loadSettings() {
    final settings = GlobalSettingsService.to;
    clinicNameController.text = settings.clinicName.value;
    clinicPhoneController.text = settings.clinicPhone.value;
    clinicAddressController.text = settings.clinicAddress.value;
    clinicLogoPath.value = settings.clinicLogoPath.value;

    zaloAppIdController.text = settings.zaloAppId.value;
    zaloSecretKeyController.text = settings.zaloSecretKey.value;
    zaloOaIdController.text = settings.zaloOaId.value;
    zaloRefreshTokenController.text = settings.zaloRefreshToken.value;
  }

  Future<void> saveSettings() async {
    isLoading.value = true;
    try {
      await GlobalSettingsService.to.updateSettings(
        name: clinicNameController.text,
        address: clinicAddressController.text,
        phone: clinicPhoneController.text,
        logoPath: clinicLogoPath.value,
        zaloAppId: zaloAppIdController.text,
        zaloSecretKey: zaloSecretKeyController.text,
        zaloOaId: zaloOaIdController.text,
        zaloRefreshToken: zaloRefreshTokenController.text,
      );

      Get.snackbar(
        'Thành công',
        'Đã lưu cài đặt',
        backgroundColor: Colors.green.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể lưu cài đặt: $e',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      clinicLogoPath.value = result.files.single.path;
    }
  }

  /// Import services
  Future<void> importServices() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        isLoading.value = true;

        final filePath = result.files.single.path;
        if (filePath == null) return;

        final excelService = Get.find<ExcelService>();
        final services = await excelService.importServices(filePath);

        if (services.isNotEmpty) {
          final count = await excelService.saveServicesToDb(services);
          Get.snackbar(
            'Thành công',
            'Đã nhập $count dịch vụ',
            backgroundColor: Colors.green.shade100,
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          Get.snackbar(
            'Thông báo',
            'Không tìm thấy dữ liệu hợp lệ',
            backgroundColor: Colors.orange.shade100,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Nhập file thất bại: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Export services
  Future<void> exportServices() async {
    try {
      isLoading.value = true;
      final db = await DatabaseProvider.instance.database;
      final result = await db.query('services');
      final services = result.map((e) => ServiceModel.fromJson(e)).toList();

      final excelService = Get.find<ExcelService>();
      final path = await excelService.exportServices(services);

      if (path != null) {
        // Option to open file or share
        Get.snackbar(
          'Thành công',
          'Đã xuất file: $path',
          backgroundColor: Colors.green.shade100,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Xuất file thất bại: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
