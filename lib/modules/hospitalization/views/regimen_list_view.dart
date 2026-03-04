import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/hospitalization_models.dart';
import '../controllers/regimen_controller.dart';
import 'regimen_editor_view.dart';

class RegimenListView extends StatelessWidget {
  const RegimenListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RegimenController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phác Đồ Điều Trị'),
        actions: [
          IconButton(
            onPressed: () => Get.to(() => const RegimenEditorView()),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.regimens.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text('Chưa có phác đồ mẫu nào'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.to(() => const RegimenEditorView()),
                  child: const Text('Tạo mới ngay'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.regimens.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final regimen = controller.regimens[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  regimen.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (regimen.description != null &&
                        regimen.description!.isNotEmpty)
                      Text(
                        regimen.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${regimen.items.length} mục (thuốc/dịch vụ)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Get.to(() => RegimenEditorView(regimen: regimen));
                    } else if (value == 'delete') {
                      _confirmDelete(controller, regimen);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Chỉnh sửa'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                onTap: () => Get.to(() => RegimenEditorView(regimen: regimen)),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmDelete(RegimenController controller, RegimenModel regimen) {
    Get.dialog(
      AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa phác đồ "${regimen.name}"?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteRegimen(regimen.id);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
