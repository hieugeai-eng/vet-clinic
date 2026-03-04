import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/widgets/pro_widgets.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/main_layout.dart';
import '../controllers/staff_controller.dart';
import 'staff_form_dialog.dart';

class StaffListView extends StatelessWidget {
  const StaffListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StaffController());

    return MainLayout(
      title: 'Quản Lý Dân Sự',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.dialog(const StaffFormDialog()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm nhân viên'),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.staffList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có nhân viên nào',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.staffList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final staff = controller.staffList[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: staff.isActive
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  child: Icon(
                    Icons.person,
                    color: staff.isActive ? AppColors.primary : Colors.grey,
                    size: 28,
                  ),
                ),
                title: Text(
                  staff.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: staff.isActive ? AppColors.text : Colors.grey,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            staff.roleName,
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (staff.phone != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            staff.phone!,
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: staff.isActive,
                      onChanged: (_) => controller.toggleActive(staff),
                      activeColor: AppColors.primary,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.blue.shade600,
                      ),
                      onPressed: () =>
                          Get.dialog(StaffFormDialog(staff: staff)),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      onPressed: () => _confirmDelete(controller, staff.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmDelete(StaffController controller, String id) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa nhân viên này khỏi hệ thống?',
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteStaff(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
