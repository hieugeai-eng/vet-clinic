import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../../../data/models/service_model.dart';
import '../../../../../data/providers/local/database_provider.dart';
import '../../../../../data/repositories/base_sync_repository.dart';
import '../../../../../core/sync/sync_engine.dart';
import '../../../../../core/services/auth_service.dart';

class ServiceController extends GetxController with SyncCapable {
  final _uuid = const Uuid();
  final isLoading = false.obs;
  final services = <ServiceModel>[].obs;

  // Form
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final unitController = TextEditingController();
  final categoryValue = 'exam'.obs;
  final editingId = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    loadServices();

    // Auto-refresh when sync pulls new data
    if (Get.isRegistered<SyncEngine>()) {
      ever(Get.find<SyncEngine>().syncVersion, (_) {
        loadServices();
      });
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    priceController.dispose();
    unitController.dispose();
    super.onClose();
  }

  Future<void> loadServices() async {
    isLoading.value = true;
    try {
      final database = await db;
      final results = await database.query(
        'services',
        where: '_is_deleted = 0 OR _is_deleted IS NULL',
        orderBy: 'name ASC',
      );
      services.value = results.map((s) => ServiceModel.fromJson(s)).toList();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải dịch vụ: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void showForm({ServiceModel? service}) {
    if (service != null) {
      editingId.value = service.id;
      nameController.text = service.name;
      priceController.text = service.basePrice.toStringAsFixed(0);
      unitController.text = service.unit ?? '';
      categoryValue.value = service.category ?? 'other';
    } else {
      editingId.value = null;
      nameController.clear();
      priceController.clear();
      unitController.clear();
      categoryValue.value = 'other';
    }
  }

  Future<void> saveService() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final now = DateTime.now();

      final service = ServiceModel(
        id: editingId.value ?? _uuid.v4(),
        name: nameController.text,
        basePrice: double.tryParse(priceController.text) ?? 0,
        unit: unitController.text,
        category: categoryValue.value,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final data = service.toJson();

      // Inject clinic_id
      if (Get.isRegistered<AuthService>()) {
        final clinicId = AuthService.to.currentProfile.value?.clinicId;
        if (clinicId != null && data['clinic_id'] == null) {
          data['clinic_id'] = clinicId;
        }
      }

      if (editingId.value != null) {
        await updateWithSync(
          table: 'services',
          recordId: service.id,
          data: data,
        );
      } else {
        await insertWithSync(table: 'services', data: data, id: service.id);
      }

      await loadServices();
      Get.back(); // Close dialog
      Get.snackbar('Thành công', 'Đã lưu dịch vụ');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể lưu dịch vụ: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteService(String id) async {
    try {
      await deleteWithSync(table: 'services', recordId: id, softDelete: true);
      await loadServices();
      Get.snackbar('Thành công', 'Đã xóa dịch vụ');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa dịch vụ: $e');
    }
  }
}
