import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:okada_vet_clinic/core/constants/app_colors.dart';
import 'package:okada_vet_clinic/core/utils/formatters.dart';
import 'package:okada_vet_clinic/routes/app_routes.dart';
import 'package:okada_vet_clinic/modules/medical_cases/controllers/case_list_controller.dart';
import 'package:okada_vet_clinic/core/widgets/app_button.dart';
import 'package:okada_vet_clinic/core/widgets/selection_chip.dart';
import 'package:okada_vet_clinic/core/widgets/status_badge.dart';

class CaseListDesktopView extends GetView<CaseListController> {
  const CaseListDesktopView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar (Search & Filters)
        _buildToolbar(context),

        // Table Header
        _buildTableHeader(),

        // Table Content
        Expanded(
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
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có ca bệnh nào',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: controller.filteredCases.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final caseData = controller.filteredCases[index];
                return _buildTableRow(context, caseData);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: controller.setSearchQuery,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm theo mã, tên khách, số điện thoại...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.slate600),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.slate600,
                    size: 18,
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 40),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ), // Reduced vertical padding
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Status Filters
          Obx(
            () => Row(
              children: [
                _buildFilterButton('Tất cả', 'all'),
                const SizedBox(width: 8),
                _buildFilterButton('Đang điều trị', 'active'),
                const SizedBox(width: 8),
                _buildFilterButton('Hoàn thành', 'completed'),
              ],
            ),
          ),

          const SizedBox(width: 16),
          AppButton(
            label: 'Tạo Ca Mới',
            icon: Icons.add,
            onPressed: () => Get.toNamed(Routes.caseCreate),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ), // Match original dimensions
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'Mã Ca',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              'Thú Cưng',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Khách Hàng',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Tiên Lượng',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Ngày Nhập',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Tổng Tiền',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Trạng Thái',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, dynamic caseData) {
    final status = caseData.status;

    return InkWell(
      onTap: () {
        try {
          Get.toNamed(Routes.caseCreate, arguments: caseData);
        } catch (e) {
          debugPrint('Case navigation error: $e');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                '#${caseData.caseCode}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    caseData.species?.toLowerCase() == 'meo'
                        ? Icons.pets
                        : Icons.pets,
                    size: 18,
                    color: AppColors.slate600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    caseData.petName ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caseData.customerName ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caseData.phone ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 1, child: _buildPrognosisText(caseData.prognosis)),
            SizedBox(
              width: 120,
              child: Text(
                Formatters.formatDateTime(caseData.admissionDate),
                style: const TextStyle(fontSize: 13, color: AppColors.slate900),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                Formatters.formatCurrency(caseData.totalEstimate),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.slate900,
                ),
              ),
            ),
            SizedBox(width: 120, child: _buildStatusBadge(status)),
            SizedBox(
              width: 48,
              child: GestureDetector(
                onTapDown: (details) {
                  _showCaseActions(context, caseData, details.globalPosition);
                },
                child: const Icon(Icons.more_vert, color: AppColors.slate600),
              ),
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
        label = 'Tốt';
        break;
      case 'bad':
        color = AppColors.error;
        label = 'Xấu';
        break;
      default:
        color = AppColors.warning;
        label = 'Dè dặt';
    }
    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w500),
    );
  }

  void _showCaseActions(
    BuildContext context,
    dynamic caseData,
    Offset tapPosition,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx + 1,
        tapPosition.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.visibility, color: AppColors.info),
            title: Text('Xem chi tiết'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => Get.toNamed(Routes.caseCreate, arguments: caseData),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.delete, color: AppColors.error),
            title: Text('Xóa hồ sơ'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // Need a slight delay because tap immediately closes menu first
            Future.delayed(const Duration(milliseconds: 100), () {
              _confirmDelete(context, caseData.id);
            });
          },
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    Get.dialog(
      AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ca bệnh này?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
