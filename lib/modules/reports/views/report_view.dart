import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../controllers/report_controller.dart';
import 'mobile/report_mobile_view.dart';

class ReportView extends GetView<ReportController> {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Báo Cáo Thống Kê',
      actions: [
        IconButton(
          onPressed: controller.exportToExcel,
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Xuất báo cáo Excel',
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () {
            controller.loadDailyReport();
            controller.loadMonthlyReport();
            controller.loadInventoryReport();
          },
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: AppColors.primary,
          ),
        ),
      ],

      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return const ReportMobileView();
          }
          return Column(
            children: [
              _buildTabs(),
              const SizedBox(height: 6),
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Obx(
          () => Row(
            children: [
              Expanded(child: _buildTabItem('Báo Cáo Ngày', 0, Icons.today)),
              Expanded(
                child: _buildTabItem('Báo Cáo Tháng', 1, Icons.calendar_month),
              ),
              Expanded(child: _buildTabItem('Kho Hàng', 2, Icons.inventory_2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index, IconData icon) {
    final isSelected = controller.viewTab.value == index;
    return InkWell(
      onTap: () => controller.setViewTab(index),
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      switch (controller.viewTab.value) {
        case 0:
          return _buildDailyReport();
        case 1:
          return _buildMonthlyReport();
        case 2:
          return _buildInventoryReport();
        default:
          return _buildDailyReport();
      }
    });
  }

  Widget _buildDailyReport() {
    return Column(
      children: [
        // Date selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: controller.previousDay,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade50,
                ),
              ),
              Obx(
                () => InkWell(
                  onTap: () => _selectDate(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            Text(
                              controller.formatDate(
                                controller.selectedDate.value,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: controller.nextDay,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Stats
        Expanded(
          child: Obx(
            () => controller.dailyReport.value == null
                ? Center(
                    child: Text(
                      'Không có dữ liệu',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  )
                : _buildDailyStats(),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: Get.context!,
      initialDate: controller.selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      controller.setDate(date);
    }
  }

  Widget _buildDailyStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Main stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Ca Bệnh',
                  controller.dailyCases.toString(),
                  Icons.medical_services_outlined,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Khám',
                  controller.formatCurrency(controller.dailyRevenue),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Petshop',
                  controller.formatCurrency(controller.dailyPetshop),
                  Icons.storefront_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Thu Khác',
                  controller.formatCurrency(controller.dailyOtherIncome),
                  Icons.add_circle_outline,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Chi Phí',
                  controller.formatCurrency(controller.dailyExpenses),
                  Icons.money_off_outlined,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildStatCard(
                  'Lợi Nhuận Ròng',
                  controller.formatCurrency(controller.dailyProfit),
                  Icons.trending_up,
                  controller.dailyProfit >= 0 ? Colors.green : Colors.red,
                  large: true,
                  isProfit: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyReport() {
    return Column(
      children: [
        // Month selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: controller.previousMonth,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade50,
                ),
              ),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        controller.formatMonth(
                          controller.selectedYear.value,
                          controller.selectedMonth.value,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: controller.nextMonth,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Stats
        Expanded(
          child: Obx(
            () => controller.monthlyReport.value == null
                ? Center(
                    child: Text(
                      'Không có dữ liệu',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  )
                : _buildMonthlyStats(),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Overview stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Ca Bệnh',
                  controller.monthlyCases.toString(),
                  Icons.medical_services_outlined,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Hoàn Thành',
                  controller.monthlyCompletedCases.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Khám',
                  controller.formatCurrency(controller.monthlyRevenue),
                  Icons.attach_money,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Petshop',
                  controller.formatCurrency(controller.monthlyPetshop),
                  Icons.storefront_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Thu Khác',
                  controller.formatCurrency(controller.monthlyOtherIncome),
                  Icons.add_circle_outline,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Profit/Loss
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Tổng Chi Phí',
                  controller.formatCurrency(controller.monthlyExpenses),
                  Icons.money_off_outlined,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildStatCard(
                  'Lợi Nhuận Ròng',
                  controller.formatCurrency(controller.monthlyProfit),
                  Icons.trending_up,
                  controller.monthlyProfit >= 0 ? Colors.green : Colors.red,
                  large: true,
                  isProfit: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Service breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expenses by category
              Expanded(
                child: _buildCategoryBreakdown(
                  'Chi Phí Theo Danh Mục',
                  controller.expensesByCategory,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 24),
              // Service stats
              Expanded(child: _buildServiceStats()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    String title,
    Map<String, double> data,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Center(child: Text('Khong co du lieu'))
            else
              ...data.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(e.key)),
                      Expanded(
                        flex: 3,
                        child: LinearProgressIndicator(
                          value: data.values.isNotEmpty
                              ? e.value /
                                    data.values.reduce((a, b) => a > b ? a : b)
                              : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        controller.formatCurrency(e.value),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStats() {
    final stats = controller.serviceStats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dich Vu Pho Bien',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (stats.isEmpty)
              const Center(child: Text('Khong co du lieu'))
            else
              ...stats
                  .take(10)
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(s['service_name'] ?? ''),
                          ),
                          Text(
                            '${s['total_quantity'] ?? 0}',
                            style: TextStyle(color: Colors.grey.shade900),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            controller.formatCurrency(
                              (s['total_revenue'] as num?)?.toDouble() ?? 0,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryReport() {
    return Obx(() {
      final report = controller.inventoryReport.value;
      if (report == null) {
        return Center(
          child: Text(
            'Không có dữ liệu',
            style: TextStyle(color: Colors.grey.shade800),
          ),
        );
      }

      final medicine = report['medicine'] as Map<String, dynamic>?;
      final products = report['products'] as Map<String, dynamic>?;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Medicine inventory
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_outlined,
                          size: 28,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Kho Thuốc & Dịch Vụ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInventoryStat(
                          'Tổng Loại',
                          '${medicine?['total_items'] ?? 0}',
                          Icons.inventory_2_outlined,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInventoryStat(
                          'Giá Trị Kho',
                          controller.formatCurrency(
                            (medicine?['total_value'] as num?)?.toDouble() ?? 0,
                          ),
                          Icons.account_balance_wallet_outlined,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInventoryStat(
                          'Sắp Hết',
                          '${medicine?['low_stock_items'] ?? 0}',
                          Icons.warning_amber_rounded,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Products inventory
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 28,
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Kho Petshop',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInventoryStat(
                          'Tổng Sản Phẩm',
                          '${products?['total_items'] ?? 0}',
                          Icons.inventory_2_outlined,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInventoryStat(
                          'Giá Trị Kho',
                          controller.formatCurrency(
                            (products?['total_value'] as num?)?.toDouble() ?? 0,
                          ),
                          Icons.account_balance_wallet_outlined,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInventoryStat(
                          'Sắp Hết',
                          '${products?['low_stock_items'] ?? 0}',
                          Icons.warning_amber_rounded,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }

  Widget _buildInventoryStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool large = false,
    bool isProfit = false,
  }) {
    return Container(
      padding: EdgeInsets.all(large ? 10 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: large ? 26 : 22,
                height: large ? 26 : 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, color: color, size: large ? 14 : 11),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: large ? 8 : 7,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 16 : 13,
                fontWeight: FontWeight.w700,
                color: isProfit ? color : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
