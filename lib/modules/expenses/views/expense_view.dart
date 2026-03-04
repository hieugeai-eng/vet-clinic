import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../../../data/models/expense_model.dart';
import '../controllers/expense_controller.dart';
import 'expense_form_dialog.dart';

class ExpenseView extends GetView<ExpenseController> {
  const ExpenseView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Sổ Chi Tiêu',
      actions: [
        IconButton(
          onPressed: controller.loadExpenses,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (PermissionService.to.can(AppPermission.expensesCreate)) {
            Get.dialog(const ExpenseFormDialog());
          } else {
            Get.snackbar(
              'Không có quyền',
              'Bạn không được phép thêm khoản chi',
              backgroundColor: Colors.orange.shade100,
            );
          }
        },
        label: const Text('Thêm giao dịch'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
      child: Column(
        children: [
          _buildMonthSelector(),
          _buildSummary(),
          Expanded(child: _buildExpenseList()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: controller.previousMonth,
              icon: const Icon(Icons.chevron_left, size: 14),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          ),
          Obx(
            () => Column(
              children: [
                Text(
                  'Tháng ${controller.selectedMonth}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${controller.selectedYear}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: controller.nextMonth,
              icon: const Icon(Icons.chevron_right, size: 14),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: isMobile
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 16) / 3,
                child: _buildStatCard(
                  'Tổng Thu',
                  controller.totalIncome,
                  Colors.green,
                  Icons.arrow_downward_rounded,
                ),
              ),
              SizedBox(
                width: isMobile
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 16) / 3,
                child: _buildStatCard(
                  'Tổng Chi',
                  controller.totalExpense,
                  Colors.red,
                  Icons.arrow_upward_rounded,
                ),
              ),
              SizedBox(
                width: isMobile
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 3,
                child: _buildStatCard(
                  'Cân Đối',
                  controller.balance,
                  AppColors.primary,
                  Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    RxDouble valueRx,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Obx(
                    () => Text(
                      controller.formatCurrency(valueRx.value),
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.expenses.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Chưa có giao dịch nào trong tháng này',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(4),
        itemCount: controller.expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final expense = controller.expenses[index];
          final isIncome = expense.type == 'income';
          final color = isIncome ? Colors.green : Colors.red;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: ListTile(
                onTap: () {
                  if (PermissionService.to.can(AppPermission.expensesEdit)) {
                    Get.dialog(ExpenseFormDialog(expense: expense));
                  } else {
                    Get.snackbar(
                      'Không có quyền',
                      'Bạn không được phép sửa khoản chi',
                      backgroundColor: Colors.orange.shade100,
                    );
                  }
                },
                onLongPress: () {
                  if (PermissionService.to.can(AppPermission.expensesDelete)) {
                    _confirmDelete(expense.id);
                  } else {
                    Get.snackbar(
                      'Không có quyền',
                      'Bạn không được phép xóa khoản chi',
                      backgroundColor: Colors.orange.shade100,
                    );
                  }
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                dense: true,
                leading: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
                title: Text(
                  expense.content,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 10,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              controller.formatDate(expense.date),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            expense.category,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: expense.paymentMethod == 'cash'
                                ? Colors.orange.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            expense.paymentMethod == 'cash'
                                ? 'Tiền mặt'
                                : 'Chuyển khoản',
                            style: TextStyle(
                              color: expense.paymentMethod == 'cash'
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (expense.staffId != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        'Người GD: ${expense.staffId}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}${controller.formatCurrency(expense.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                    if (expense.quantity != null && expense.quantity! > 1)
                      Text(
                        'SL: ${expense.quantity} ${expense.unit ?? ''}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  void _confirmDelete(String id) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa giao dịch này không?',
          style: TextStyle(fontSize: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteExpense(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Xăng xe ca':
        return FontAwesomeIcons.gasPump;
      case 'Xét nghiệm':
        return FontAwesomeIcons.microscope;
      case 'Thuốc điều trị':
        return FontAwesomeIcons.pills;
      case 'Vật tư':
        return FontAwesomeIcons.boxOpen;
      case 'Tiền ăn':
        return FontAwesomeIcons.utensils;
      case 'Lương':
        return FontAwesomeIcons.moneyBillWave;
      case 'Điện nước':
        return FontAwesomeIcons.bolt;
      default:
        return FontAwesomeIcons.moneyBill;
    }
  }
}
