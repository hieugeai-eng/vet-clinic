import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:okada_vet_clinic/core/constants/app_colors.dart';
import 'package:okada_vet_clinic/core/utils/formatters.dart';
import 'package:okada_vet_clinic/routes/app_routes.dart';
import 'package:okada_vet_clinic/modules/medical_cases/controllers/case_list_controller.dart';
import 'package:okada_vet_clinic/core/widgets/app_button.dart';
import 'package:okada_vet_clinic/core/widgets/app_card.dart';
import 'package:okada_vet_clinic/core/widgets/selection_chip.dart';
import 'package:okada_vet_clinic/core/widgets/status_badge.dart';

class CaseListMobileView extends GetView<CaseListController> {
  const CaseListMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Obx(
            () => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatChip(
                          'Tổng',
                          controller.totalCount.toString(),
                          Icons.folder,
                          AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        _buildStatChip(
                          'Đang trị',
                          controller.activeCount.toString(),
                          Icons.medical_services,
                          AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        _buildStatChip(
                          'Xong',
                          controller.completedCount.toString(),
                          Icons.check_circle,
                          AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Tạo',
                  icon: Icons.add,
                  onPressed: () => Get.toNamed(Routes.caseCreate),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Filters
        _buildFilters(context),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => controller.refresh(),
            child: Obx(() {
              if (controller.isLoading.value && controller.cases.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.filteredCases.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chưa có ca bệnh nào',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Bắt đầu khám',
                        icon: Icons.add,
                        onPressed: () => Get.toNamed(Routes.caseCreate),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount:
                    controller.filteredCases.length +
                    (controller.hasMore.value ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index >= controller.filteredCases.length) {
                    controller.loadCases();
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _buildCaseCard(
                    context,
                    controller.filteredCases[index],
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    onChanged: controller.setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo mã, tên khách...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.slate600,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.slate600,
                        size: 16,
                      ),
                      prefixIconConstraints: BoxConstraints(minWidth: 32),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.filter_list,
                    color: AppColors.slate900,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(
            () => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Đang điều trị', 'active'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Hoàn thành', 'completed'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = controller.statusFilter.value == value;
    return SelectionChip(
      label: label,
      isSelected: isSelected,
      onTap: () => controller.setStatusFilter(value),
      selectedColor: AppColors.primary,
      selectedBgColor: AppColors.primaryLight,
      selectedBorderColor: const Color(0xFFC4B5FD),
    );
  }

  Widget _buildCaseCard(BuildContext context, dynamic caseData) {
    final status = caseData.status;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => Get.toNamed(Routes.caseCreate, arguments: caseData),
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${caseData.caseCode}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    caseData.species?.toLowerCase() == 'meo'
                        ? Icons.pets
                        : Icons.pets,
                    color: AppColors.info,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caseData.petName ?? 'Không tên',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'KH: ${caseData.customerName ?? 'N/A'}${caseData.staffName?.isNotEmpty == true ? ' - NV: ${caseData.staffName}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(caseData.totalEstimate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatDateTime(caseData.admissionDate),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.slate200),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart_outlined,
                      size: 14,
                      color: AppColors.slate600,
                    ),
                    const SizedBox(width: 4),
                    _buildPrognosisText(caseData.prognosis),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: AppColors.slate800,
                  ),
                  onPressed: () => _showCaseActions(context, caseData),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    if (status == 'active')
      return const StatusBadge(
        label: 'Đang điều trị',
        type: StatusBadgeType.warning,
      );
    if (status == 'completed')
      return const StatusBadge(
        label: 'Hoàn thành',
        type: StatusBadgeType.success,
      );
    return const StatusBadge(label: 'N/A', type: StatusBadgeType.neutral);
  }

  Widget _buildPrognosisText(String prognosis) {
    Color color;
    String label;
    switch (prognosis) {
      case 'good':
        color = AppColors.success;
        label = 'Tiên lượng Tốt';
        break;
      case 'bad':
        color = AppColors.error;
        label = 'Tiên lượng Xấu';
        break;
      default:
        color = AppColors.warning;
        label = 'Tiên lượng Dè dặt';
    }
    return Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  void _showCaseActions(BuildContext context, dynamic caseData) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.visibility, color: AppColors.info),
              ),
              title: const Text(
                'Xem chi tiết',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate800,
                ),
              ),
              onTap: () {
                Get.back();
                Get.toNamed(Routes.caseCreate, arguments: caseData);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print, color: AppColors.primary),
              ),
              title: const Text(
                'In bệnh án',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate800,
                ),
              ),
              onTap: () {
                Get.back();
                // Print logic
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: AppColors.error),
              ),
              title: const Text(
                'Xóa hồ sơ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Get.back();
                _confirmDelete(context, caseData.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc muốn xóa ca bệnh này? Hành động này không thể hoàn tác.',
          style: TextStyle(color: AppColors.slate900),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.slate900),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteCase(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Xóa Vĩnh Viễn'),
          ),
        ],
      ),
    );
  }
}
