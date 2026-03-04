import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../../../data/models/cage_model.dart';
import '../controllers/cage_controller.dart';

class CageConfigView extends StatelessWidget {
  const CageConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CageController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Cấu Hình Chuồng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.cages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có chuồng nào',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context, controller),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm Chuồng Mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: controller.cages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final cage = controller.cages[index];
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
              child: Builder(
                builder: (ctx) {
                  final isNarrow = MediaQuery.of(ctx).size.width < 600;
                  return ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getTypeColor(cage.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTypeIcon(cage.type),
                        color: _getTypeColor(cage.type),
                      ),
                    ),
                    title: Text(
                      cage.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_getTypeName(cage.type)} • ${cage.price.toInt()}đ/ngày',
                        style: TextStyle(color: Colors.grey.shade900),
                      ),
                    ),
                    trailing: isNarrow
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: cage.status != 'maintenance',
                                activeColor: Colors.green,
                                inactiveTrackColor: Colors.grey.shade200,
                                onChanged: (_) =>
                                    controller.toggleMaintenance(cage),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(context, controller, cage);
                                  } else if (value == 'delete') {
                                    _confirmDelete(
                                      context,
                                      controller,
                                      cage.id,
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      title: Text('Sửa'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      title: Text('Xóa'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: cage.status != 'maintenance',
                                activeColor: Colors.green,
                                inactiveTrackColor: Colors.grey.shade200,
                                onChanged: (_) =>
                                    controller.toggleMaintenance(cage),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.blue.shade400,
                                ),
                                onPressed: () =>
                                    _showEditDialog(context, controller, cage),
                                tooltip: 'Sửa',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red.shade400,
                                ),
                                onPressed: () => _confirmDelete(
                                  context,
                                  controller,
                                  cage.id,
                                ),
                                tooltip: 'Xóa',
                              ),
                            ],
                          ),
                  );
                },
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Thêm Chuồng'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'dog':
        return Colors.blue;
      case 'cat':
        return Colors.orange;
      case 'isolation':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'dog':
        return Icons.pets;
      case 'cat':
        return Icons.catching_pokemon;
      case 'isolation':
        return Icons.medical_services;
      default:
        return Icons.home;
    }
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'dog':
        return 'Chó';
      case 'cat':
        return 'Mèo';
      case 'isolation':
        return 'Cách ly';
      default:
        return 'Khác';
    }
  }

  // Dialogs logic (Add/Edit)
  void _showAddDialog(BuildContext context, CageController controller) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final type = 'dog'.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 450),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Thêm Chuồng Mới',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ProTextField(
                label: 'Tên chuồng (Ví dụ: A1)',
                controller: nameController,
                prefixIcon: Icons.door_front_door_outlined,
              ),
              const SizedBox(height: 16),

              Obx(
                () => DropdownButtonFormField<String>(
                  value: type.value,
                  decoration: InputDecoration(
                    labelText: 'Loại',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'dog', child: Text('Chó')),
                    DropdownMenuItem(value: 'cat', child: Text('Mèo')),
                    DropdownMenuItem(
                      value: 'isolation',
                      child: Text('Cách ly'),
                    ),
                  ],
                  onChanged: (v) => type.value = v!,
                ),
              ),
              const SizedBox(height: 16),

              ProTextField(
                label: 'Giá tiền/ngày',
                controller: priceController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
                suffixText: 'VNĐ',
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          priceController.text.isNotEmpty) {
                        controller.addCage(
                          nameController.text,
                          type.value,
                          double.tryParse(priceController.text) ?? 0,
                        );
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Thêm Ngay'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    CageController controller,
    CageModel cage,
  ) {
    final nameController = TextEditingController(text: cage.name);
    final priceController = TextEditingController(text: cage.price.toString());
    final type = cage.type.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 450),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Sửa Thông Tin',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ProTextField(
                label: 'Tên chuồng',
                controller: nameController,
                prefixIcon: Icons.door_front_door_outlined,
              ),
              const SizedBox(height: 16),

              Obx(
                () => DropdownButtonFormField<String>(
                  value: type.value,
                  decoration: InputDecoration(
                    labelText: 'Loại',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'dog', child: Text('Chó')),
                    DropdownMenuItem(value: 'cat', child: Text('Mèo')),
                    DropdownMenuItem(
                      value: 'isolation',
                      child: Text('Cách ly'),
                    ),
                  ],
                  onChanged: (v) => type.value = v!,
                ),
              ),
              const SizedBox(height: 16),

              ProTextField(
                label: 'Giá tiền/ngày',
                controller: priceController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
                suffixText: 'VNĐ',
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      controller.updateCage(
                        cage.copyWith(
                          name: nameController.text,
                          type: type.value,
                          price: double.tryParse(priceController.text) ?? 0,
                        ),
                      );
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cập Nhật'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CageController controller,
    String id,
  ) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Xác nhận xóa'),
          ],
        ),
        content: const Text(
          'Bạn có chắc muốn xóa chuồng này? Hành động này không thể hoàn tác.',
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              controller.deleteCage(id);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xóa Vĩnh Viễn'),
          ),
        ],
      ),
    );
  }
}
