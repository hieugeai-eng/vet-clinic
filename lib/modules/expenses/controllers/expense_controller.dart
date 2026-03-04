import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../data/models/expense_model.dart';
import '../repositories/expense_repository.dart';

class ExpenseController extends GetxController {
  final ExpenseRepository _repository = ExpenseRepository();

  final selectedYear = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;

  final expenses = <ExpenseModel>[].obs;
  final isLoading = false.obs;

  // Stats
  final totalIncome = 0.0.obs;
  final totalExpense = 0.0.obs;
  final balance = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
    // Auto-reload when SyncEngine detects changes (e.g. after a return from Petshop)
    // debounce 500ms to avoid flooding reloads when multiple tables sync at once
    if (Get.isRegistered<SyncEngine>()) {
      debounce<int>(
        SyncEngine.to.syncVersion,
        (_) => loadExpenses(),
        time: const Duration(milliseconds: 500),
      );
    }
  }

  Future<void> loadExpenses() async {
    isLoading.value = true;
    try {
      final list = await _repository.getExpensesByMonth(
        selectedYear.value,
        selectedMonth.value,
      );
      expenses.value = list;
      _calculateTotal();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách chi phí: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateTotal() {
    double income = 0;
    double expense = 0;
    for (var e in expenses) {
      if (e.type == 'income') {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }
    totalIncome.value = income;
    totalExpense.value = expense;
    balance.value = income - expense;
  }

  void previousMonth() {
    if (selectedMonth.value == 1) {
      selectedYear.value--;
      selectedMonth.value = 12;
    } else {
      selectedMonth.value--;
    }
    loadExpenses();
  }

  void nextMonth() {
    if (selectedMonth.value == 12) {
      selectedYear.value++;
      selectedMonth.value = 1;
    } else {
      selectedMonth.value++;
    }
    loadExpenses();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    if (!PermissionService.to.can(AppPermission.expensesCreate)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép thêm khoản chi',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    try {
      await _repository.addExpense(expense);
      loadExpenses();
      Get.snackbar(
        'Thành công',
        'Đã thêm khoản chi mới',
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể thêm khoản chi: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    if (!PermissionService.to.can(AppPermission.expensesEdit)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép sửa khoản chi',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    try {
      await _repository.updateExpense(expense);
      loadExpenses();
      Get.snackbar(
        'Thành công',
        'Đã cập nhật khoản chi',
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể cập nhật khoản chi: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> deleteExpense(String id) async {
    if (!PermissionService.to.can(AppPermission.expensesDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa khoản chi',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    try {
      await _repository.deleteExpense(id);
      loadExpenses();
      Get.snackbar(
        'Thành công',
        'Đã xóa khoản chi',
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể xóa khoản chi: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat('#,###', 'vi');
    return '${formatter.format(value)} VND';
  }

  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
