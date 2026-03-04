import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/report_repository.dart';
import '../services/excel_export_service.dart';
import '../../../core/services/zalo_service.dart';

class ReportController extends GetxController {
  final ReportRepository _reportRepository = ReportRepository();

  final isLoading = false.obs;
  final viewTab = 0.obs; // 0: daily, 1: monthly, 2: inventory

  // Daily report
  final selectedDate = DateTime.now().obs;
  final dailyReport = Rxn<Map<String, dynamic>>();

  // Monthly report
  final selectedYear = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;
  final monthlyReport = Rxn<Map<String, dynamic>>();

  // Inventory report
  final inventoryReport = Rxn<Map<String, dynamic>>();

  // Export service
  final _excelExportService = ExcelExportService();

  @override
  void onInit() {
    super.onInit();
    loadDailyReport();
    loadMonthlyReport();
    loadInventoryReport();
  }

  void setViewTab(int tab) {
    viewTab.value = tab;
  }

  // Daily report
  Future<void> loadDailyReport() async {
    isLoading.value = true;
    try {
      dailyReport.value = await _reportRepository.getDailyReport(
        selectedDate.value,
      );
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the tai bao cao ngay: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void setDate(DateTime date) {
    selectedDate.value = date;
    loadDailyReport();
  }

  void previousDay() {
    setDate(selectedDate.value.subtract(const Duration(days: 1)));
  }

  void nextDay() {
    setDate(selectedDate.value.add(const Duration(days: 1)));
  }

  // Monthly report
  Future<void> loadMonthlyReport() async {
    isLoading.value = true;
    try {
      monthlyReport.value = await _reportRepository.getMonthlyReport(
        selectedYear.value,
        selectedMonth.value,
      );
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the tai bao cao thang: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void setMonth(int year, int month) {
    selectedYear.value = year;
    selectedMonth.value = month;
    loadMonthlyReport();
  }

  void previousMonth() {
    if (selectedMonth.value == 1) {
      setMonth(selectedYear.value - 1, 12);
    } else {
      setMonth(selectedYear.value, selectedMonth.value - 1);
    }
  }

  void nextMonth() {
    if (selectedMonth.value == 12) {
      setMonth(selectedYear.value + 1, 1);
    } else {
      setMonth(selectedYear.value, selectedMonth.value + 1);
    }
  }

  // Inventory report
  Future<void> loadInventoryReport() async {
    try {
      inventoryReport.value = await _reportRepository.getInventoryReport();
    } catch (e) {
      debugPrint('Error loading inventory report: $e');
    }
  }

  // Export
  Future<void> exportToExcel() async {
    try {
      if (viewTab.value == 1) {
        // Export monthly report
        final path = await _excelExportService.exportMonthlyReport(
          selectedYear.value,
          selectedMonth.value,
        );

        if (path != null) {
          Get.snackbar(
            'Thành công',
            'Đã xuất file Excel',
            mainButton: TextButton(
              onPressed: () => ZaloService.to.shareFile(
                path,
                text:
                    'Báo cáo tháng ${selectedMonth.value}/${selectedYear.value}',
              ),
              child: const Text(
                'Gửi Zalo',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        Get.snackbar(
          'Thong bao',
          'Chuc nang xuat excel hien tai chi ho tro Bao Cao Thang',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the xuat excel: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  // Formatting helpers
  String formatCurrency(double value) {
    final formatter = NumberFormat('#,###', 'vi');
    return '${formatter.format(value)} VND';
  }

  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String formatMonth(int year, int month) {
    return DateFormat('MMMM yyyy', 'vi').format(DateTime(year, month));
  }

  // Statistics from daily report
  int get dailyCases => (dailyReport.value?['total_cases'] as int?) ?? 0;
  double get dailyRevenue =>
      (dailyReport.value?['total_collected'] as double?) ?? 0;
  double get dailyExpenses =>
      (dailyReport.value?['total_expenses'] as double?) ?? 0;
  double get dailyOtherIncome =>
      (dailyReport.value?['other_income'] as double?) ?? 0;
  double get dailyPetshop =>
      (dailyReport.value?['petshop_revenue'] as double?) ?? 0;
  double get dailyProfit =>
      dailyRevenue + dailyPetshop + dailyOtherIncome - dailyExpenses;

  // Statistics from monthly report
  int get monthlyCases => (monthlyReport.value?['total_cases'] as int?) ?? 0;
  int get monthlyCompletedCases =>
      (monthlyReport.value?['completed_cases'] as int?) ?? 0;
  double get monthlyRevenue =>
      (monthlyReport.value?['total_collected'] as double?) ?? 0;
  double get monthlyExpenses =>
      (monthlyReport.value?['total_expenses'] as double?) ?? 0;
  double get monthlyOtherIncome =>
      (monthlyReport.value?['other_income'] as double?) ?? 0;
  double get monthlyPetshop =>
      (monthlyReport.value?['petshop_revenue'] as double?) ?? 0;
  double get monthlyProfit =>
      (monthlyReport.value?['net_profit'] as double?) ?? 0;
  Map<String, double> get expensesByCategory {
    final data = monthlyReport.value?['expenses_by_category'];
    if (data is Map<String, double>) return data;
    return {};
  }

  List<Map<String, dynamic>> get serviceStats {
    final data = monthlyReport.value?['service_stats'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }
}
