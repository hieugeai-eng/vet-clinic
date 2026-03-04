import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../../../data/models/treatment_model.dart';
import '../controllers/treatment_controller.dart';

class TreatmentSheetView extends StatelessWidget {
  final String hospitalizationId;
  final String petName;

  const TreatmentSheetView({
    super.key,
    required this.hospitalizationId,
    required this.petName,
  });

  @override
  Widget build(BuildContext context) {
    // Inject controller with unique tag to support multiple open sheets if needed
    final controller = Get.put(
      TreatmentController(
        hospitalizationId: hospitalizationId,
        petName: petName,
      ),
      tag: hospitalizationId,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Phác Đồ: $petName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Tạo ngày mới',
            onPressed: controller.addNewDay,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.days.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có nhật ký điều trị.',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Days Tab Bar
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: controller.days.length,
                itemBuilder: (context, index) {
                  final day = controller.days[index];
                  final isSelected = day.id == controller.currentDayId.value;
                  return GestureDetector(
                    onTap: () => controller.selectDay(day.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('dd/MM').format(day.date),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Activities List
            Expanded(
              child: controller.activities.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionHeader('Dấu hiệu sinh tồn (Vital Signs)'),
                        ...controller.activities
                            .where((a) => a.type == 'vital')
                            .map((a) => _buildActivityTile(a, controller)),
                        const SizedBox(height: 16),

                        _buildSectionHeader('Thuốc & Điều trị (Medication)'),
                        ...controller.activities
                            .where((a) => a.type == 'medication')
                            .map((a) => _buildActivityTile(a, controller)),
                        const SizedBox(height: 16),

                        _buildSectionHeader('Sinh lý (Physiology)'),
                        ...controller.activities
                            .where((a) => a.type == 'physiology')
                            .map((a) => _buildActivityTile(a, controller)),
                      ],
                    ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActivityDialog(context, controller),
        label: const Text('Thêm Hoạt Động'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.notes, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Chưa có hoạt động nào trong ngày.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    TreatmentActivityModel activity,
    TreatmentController controller,
  ) {
    IconData icon;
    Color color;

    switch (activity.type) {
      case 'vital':
        icon = Icons.monitor_heart;
        color = Colors.red;
        break;
      case 'medication':
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case 'physiology':
        icon = Icons.wc;
        color = Colors.green;
        break;
      default:
        icon = Icons.circle;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          activity.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Kết quả: ${activity.value}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activity.time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red.shade300,
              ),
              onPressed: () => controller.deleteActivity(activity.id),
              tooltip: 'Xóa',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(
    BuildContext context,
    TreatmentController controller,
  ) {
    final type = 'vital'.obs;
    final nameController = TextEditingController();
    final valueController = TextEditingController();

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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.note_add_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Ghi Nhật Ký',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Type Selector
              Obx(
                () => SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'vital',
                      label: Text('Sinh hiệu'),
                      icon: Icon(Icons.monitor_heart),
                    ),
                    ButtonSegment(
                      value: 'medication',
                      label: Text('Thuốc'),
                      icon: Icon(Icons.medication),
                    ),
                    ButtonSegment(
                      value: 'physiology',
                      label: Text('Sinh lý'),
                      icon: Icon(Icons.wc),
                    ),
                  ],
                  selected: {type.value},
                  onSelectionChanged: (Set<String> newSelection) {
                    type.value = newSelection.first;
                    // Preset common activity names
                    if (type.value == 'vital') nameController.text = 'Nhiệt độ';
                    if (type.value == 'medication')
                      nameController.text = 'Tiêm';
                    if (type.value == 'physiology')
                      nameController.text = 'Ăn uống';
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ProTextField(
                label: 'Tên hoạt động (VD: Nhiệt độ, Tiêm K/S...)',
                controller: nameController,
                prefixIcon: Icons.edit_note,
              ),
              const SizedBox(height: 16),

              ProTextField(
                label: 'Kết quả (VD: 38.5, Đã tiêm, Tốt...)',
                controller: valueController,
                prefixIcon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 16),

              // Staff Selector
              Obx(
                () => DropdownButtonFormField<String>(
                  value: controller.selectedStaffId.value.isEmpty
                      ? null
                      : controller.selectedStaffId.value,
                  decoration: InputDecoration(
                    labelText: 'Người thực hiện',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: controller.staffList
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      controller.selectedStaffId.value = val ?? '',
                ),
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
                          valueController.text.isNotEmpty) {
                        controller.addActivity(
                          type: type.value,
                          name: nameController.text,
                          value: valueController.text,
                          performerId: controller.selectedStaffId.value.isEmpty
                              ? null
                              : controller.selectedStaffId.value,
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
                    child: const Text('Lưu Hoạt Động'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
