import 'dart:convert';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/hospitalization_models.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/base_sync_repository.dart';
import '../../../core/sync/sync_engine.dart';

class RegimenController extends GetxController with SyncCapable {
  final uuid = const Uuid();
  final isLoading = false.obs;
  final regimens = <RegimenModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadRegimens();
  }

  Future<void> loadRegimens() async {
    isLoading.value = true;
    try {
      final db = await DatabaseProvider.instance.database;
      final result = await db.query(
        'hospitalization_regimens',
        orderBy: 'updated_at DESC',
      );

      regimens.value = result
          .map((json) => RegimenModel.fromJson(json))
          .toList();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách phác đồ: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveRegimen(RegimenModel regimen, bool isNew) async {
    isLoading.value = true;
    try {
      final json = regimen.toJson();

      if (isNew) {
        await insertWithSync(
          table: 'hospitalization_regimens',
          data: json,
          id: regimen.id,
        );
      } else {
        await updateWithSync(
          table: 'hospitalization_regimens',
          recordId: regimen.id,
          data: json,
        );
      }

      await loadRegimens();
      Get.back();
      Get.snackbar('Thành công', 'Đã lưu phác đồ');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể lưu phác đồ: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteRegimen(String id) async {
    try {
      await deleteWithSync(
        table: 'hospitalization_regimens',
        recordId: id,
        softDelete: false,
      );
      await loadRegimens();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa phác đồ: $e');
    }
  }
}
