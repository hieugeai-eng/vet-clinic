import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/cage_model.dart';
import '../repositories/cage_repository.dart';

class CageController extends GetxController {
  final _repo = CageRepository();
  final uuid = const Uuid();

  final cages = <CageModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCages();
  }

  Future<void> loadCages() async {
    isLoading.value = true;
    try {
      cages.value = await _repo.getAllCages();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách chuồng: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addCage(String name, String type, double price) async {
    try {
      final newCage = CageModel(
        id: uuid.v4(),
        name: name,
        type: type,
        status: 'available',
        price: price,
        orderIndex: cages.length + 1,
      );
      await _repo.addCage(newCage);
      await loadCages();
      Get.back(); // Close dialog
      Get.snackbar('Thành công', 'Đã thêm chuồng mới');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể thêm chuồng: $e');
    }
  }

  Future<void> updateCage(CageModel cage) async {
    try {
      await _repo.updateCage(cage);
      await loadCages();
      Get.back();
      Get.snackbar('Thành công', 'Đã cập nhật thông tin chuồng');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể cập nhật: $e');
    }
  }

  Future<void> deleteCage(String id) async {
    try {
      await _repo.deleteCage(id);
      await loadCages();
      Get.snackbar('Thành công', 'Đã xóa chuồng');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa: $e');
    }
  }

  Future<void> toggleMaintenance(CageModel cage) async {
    final newStatus = cage.status == 'maintenance'
        ? 'available'
        : 'maintenance';
    // Prevent setting to maintenance if occupied (though occupied is computed)
    // Here we just update the base status in DB
    try {
      final updatedCage = cage.copyWith(status: newStatus);
      await _repo.updateCage(updatedCage);
      await loadCages();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể đổi trạng thái: $e');
    }
  }
}
