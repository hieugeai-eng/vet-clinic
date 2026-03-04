import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../controllers/report_controller.dart';

class ReportMobileView extends GetView<ReportController> {
  const ReportMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        const SizedBox(height: 8),
        // Export button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.exportToExcel,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Xuất báo cáo Excel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ── Tabs (icon-only on mobile) ────────────────────────────────────────
  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Obx(
        () => Row(
          children: [
            Expanded(child: _buildTabItem('Ngày', 0, Icons.today)),
            Expanded(child: _buildTabItem('Tháng', 1, Icons.calendar_month)),
            Expanded(child: _buildTabItem('Kho', 2, Icons.inventory_2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index, IconData icon) {
    final isSelected = controller.viewTab.value == index;
    return InkWell(
      onTap: () => controller.setViewTab(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade900,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade900,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────
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

  // ═══════════════════════════════════════════════════════════════════════
  //  DAILY REPORT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDailyReport() {
    return Column(
      children: [
        _buildDateSelector(),
        const SizedBox(height: 12),
        Expanded(
          child: Obx(
            () => controller.dailyReport.value == null
                ? _buildNoData()
                : _buildDailyStats(),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: controller.previousDay,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50),
          ),
          Obx(
            () => InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: Get.context!,
                  initialDate: controller.selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) controller.setDate(date);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.formatDate(controller.selectedDate.value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: controller.nextDay,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Stats stacked vertically in Wrap 2x2 instead of Row 3
          LayoutBuilder(
            builder: (context, constraints) {
              final cw = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Ca Bệnh',
                      controller.dailyCases.toString(),
                      Icons.medical_services_outlined,
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Doanh Thu Khám',
                      controller.formatCurrency(controller.dailyRevenue),
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Petshop',
                      controller.formatCurrency(controller.dailyPetshop),
                      Icons.storefront_outlined,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Chi Phí',
                      controller.formatCurrency(controller.dailyExpenses),
                      Icons.money_off_outlined,
                      Colors.red,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Profit card full width
          _buildStatCard(
            'Lợi Nhuận Ròng',
            controller.formatCurrency(controller.dailyProfit),
            Icons.trending_up,
            controller.dailyProfit >= 0 ? Colors.green : Colors.red,
            large: true,
            isProfit: true,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MONTHLY REPORT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildMonthlyReport() {
    return Column(
      children: [
        _buildMonthSelector(),
        const SizedBox(height: 12),
        Expanded(
          child: Obx(
            () => controller.monthlyReport.value == null
                ? _buildNoData()
                : _buildMonthlyStats(),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: controller.previousMonth,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50),
          ),
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    controller.formatMonth(
                      controller.selectedYear.value,
                      controller.selectedMonth.value,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
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
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Overview stats: Wrap 2x2
          LayoutBuilder(
            builder: (context, constraints) {
              final cw = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Tổng Ca',
                      controller.monthlyCases.toString(),
                      Icons.medical_services_outlined,
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Hoàn Thành',
                      controller.monthlyCompletedCases.toString(),
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Khám',
                      controller.formatCurrency(controller.monthlyRevenue),
                      Icons.attach_money,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Petshop',
                      controller.formatCurrency(controller.monthlyPetshop),
                      Icons.storefront_outlined,
                      Colors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          // Chi phí + Lợi nhuận
          LayoutBuilder(
            builder: (context, constraints) {
              final cw = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Chi Phí',
                      controller.formatCurrency(controller.monthlyExpenses),
                      Icons.money_off_outlined,
                      Colors.red,
                    ),
                  ),
                  SizedBox(
                    width: cw,
                    child: _buildStatCard(
                      'Lợi Nhuận',
                      controller.formatCurrency(controller.monthlyProfit),
                      Icons.trending_up,
                      controller.monthlyProfit >= 0 ? Colors.green : Colors.red,
                      isProfit: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Category breakdown (full width, stacked)
          _buildCategoryBreakdown(
            'Chi Phí Theo Danh Mục',
            controller.expensesByCategory,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildServiceStats(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  INVENTORY REPORT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildInventoryReport() {
    return Obx(() {
      final report = controller.inventoryReport.value;
      if (report == null) return _buildNoData();

      final medicine = report['medicine'] as Map<String, dynamic>?;
      final products = report['products'] as Map<String, dynamic>?;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // Medicine inventory
            _buildInventorySection(
              'Kho Thuốc & Dịch Vụ',
              Icons.medication_outlined,
              Colors.blue,
              medicine,
            ),
            const SizedBox(height: 12),
            // Product inventory
            _buildInventorySection(
              'Kho Petshop',
              Icons.storefront_outlined,
              Colors.orange,
              products,
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }

  Widget _buildInventorySection(
    String title,
    IconData titleIcon,
    Color color,
    Map<String, dynamic>? data,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(titleIcon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats: Column (stacked vertically)
          _buildInventoryStat(
            'Tổng Loại',
            '${data?['total_items'] ?? 0}',
            Icons.inventory_2_outlined,
            color,
          ),
          const SizedBox(height: 8),
          _buildInventoryStat(
            'Giá Trị Kho',
            controller.formatCurrency(
              (data?['total_value'] as num?)?.toDouble() ?? 0,
            ),
            Icons.account_balance_wallet_outlined,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildInventoryStat(
            'Sắp Hết',
            '${data?['low_stock_items'] ?? 0}',
            Icons.warning_amber_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool large = false,
    bool isProfit = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: large
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: large ? 24 : 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: large ? 16 : 13,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? color : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (data.isEmpty)
              const Center(child: Text('Không có dữ liệu'))
            else
              ...data.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              e.key,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            controller.formatCurrency(e.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: data.values.isNotEmpty
                            ? e.value /
                                  data.values.reduce((a, b) => a > b ? a : b)
                            : 0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dịch Vụ Phổ Biến',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (stats.isEmpty)
              const Center(child: Text('Không có dữ liệu'))
            else
              ...stats
                  .take(8)
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s['service_name'] ?? '',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${s['total_quantity'] ?? 0}',
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            controller.formatCurrency(
                              (s['total_revenue'] as num?)?.toDouble() ?? 0,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
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

  Widget _buildNoData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
