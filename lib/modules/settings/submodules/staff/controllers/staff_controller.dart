import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../../../data/models/staff_model.dart';
import '../repositories/staff_repository.dart';

class StaffController extends GetxController {
  final StaffRepository _repository = StaffRepository();
  final staffList = <StaffModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadStaff();
  }

  Future<void> loadStaff() async {
    isLoading.value = true;
    try {
      final list = await _repository.getAllStaff();
      staffList.value = list;
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách nhân viên: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addStaff(
    String name,
    String role,
    String? phone,
    String? email,
  ) async {
    try {
      final newStaff = StaffModel(
        id: const Uuid().v4(),
        name: name,
        role: role,
        phone: phone,
        email: email,
      );
      await _repository.addStaff(newStaff);
      await loadStaff();
      Get.back();
      Get.snackbar('Thành công', 'Đã thêm nhân viên mới');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể thêm nhân viên: $e');
    }
  }

  Future<void> updateStaff(StaffModel staff) async {
    try {
      await _repository.updateStaff(staff);
      await loadStaff();
      Get.back();
      Get.snackbar('Thành công', 'Đã cập nhật thông tin nhân viên');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể cập nhật nhân viên: $e');
    }
  }

  Future<void> toggleActive(StaffModel staff) async {
    try {
      final updatedStaff = staff.copyWith(isActive: !staff.isActive);
      await _repository.updateStaff(updatedStaff);
      await loadStaff();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể cập nhật trạng thái: $e');
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      await _repository.deleteStaff(id);
      await loadStaff();
      Get.snackbar('Thành công', 'Đã xóa nhân viên');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa nhân viên: $e');
    }
  }
}
