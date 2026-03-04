import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../data/models/medicine_model.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../services/excel_service.dart';

class PharmacyController extends GetxController {
  final MedicineRepository _medicineRepository = MedicineRepository();
  final ExcelService _excelService = Get.put(ExcelService());

  final isLoading = false.obs;
  final medicines = <MedicineModel>[].obs;
  final transactions = <MedicineTransactionModel>[].obs;
  final searchQuery = ''.obs;
  final viewTab = 0.obs; // 0: medicines, 1: transactions, 2: low stock
  final currentPage = 0.obs;

  // Pagination (UI-based)
  final scrollController = ScrollController();
  final int _limit = 9999; // Load all for UI pagination
  int _offset = 0;
  final hasMore = true.obs;

  // Form controllers
  final formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  final unitController = TextEditingController();
  final avgPriceController = TextEditingController();
  final stockController = TextEditingController();
  final minStockController = TextEditingController();
  final lotNumberController = TextEditingController();
  final supplierController = TextEditingController();
  final expiryDate = Rxn<DateTime>();

  // Transaction form
  final transFormKey = GlobalKey<FormState>();
  final selectedMedicineId = ''.obs;
  final transactionType = 'import'.obs;
  final quantityController = TextEditingController();
  final unitPriceController = TextEditingController();
  final purposeController = TextEditingController();
  final transNotesController = TextEditingController();
  final transactionDate = Rxn<DateTime>();

  // Current editing
  final editingMedicine = Rxn<MedicineModel>();

  @override
  void onInit() {
    super.onInit();
    loadMedicines();
    loadTransactions();

    // Auto-refresh when remote data changes via realtime sync
    if (Get.isRegistered<SyncEngine>()) {
      ever(Get.find<SyncEngine>().syncVersion, (_) {
        loadMedicines(refresh: true);
        loadTransactions();
      });
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent * 0.9 &&
        !isLoading.value &&
        hasMore.value) {
      loadMedicines();
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    codeController.dispose();
    nameController.dispose();
    unitController.dispose();
    avgPriceController.dispose();
    stockController.dispose();
    minStockController.dispose();
    lotNumberController.dispose();
    supplierController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    purposeController.dispose();
    transNotesController.dispose();
    super.onClose();
  }

  bool _isReloading = false;

  Future<void> loadMedicines({bool refresh = false}) async {
    if (refresh) {
      if (_isReloading) return;
      _isReloading = true;
      _offset = 0;
      hasMore.value = true;
      // DO NOT medicines.clear() here to prevent flashing UI when syncing
      currentPage.value = 0;
    }

    if (!refresh && (isLoading.value || !hasMore.value)) return;

    if (_offset == 0) isLoading.value = true;

    try {
      final newItems = await _medicineRepository.getAll(
        limit: _limit,
        offset: _offset,
      );

      if (newItems.length < _limit) {
        hasMore.value = false;
      }

      if (refresh) {
        medicines.value = newItems;
      } else {
        final existingIds = medicines.map((e) => e.id).toSet();
        final filteredNew = newItems
            .where((e) => !existingIds.contains(e.id))
            .toList();
        medicines.addAll(filteredNew);
      }
      _offset += newItems.length;
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the tai danh sach thuoc: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
      if (refresh) _isReloading = false;
    }
  }

  Future<void> loadTransactions() async {
    try {
      transactions.value = await _medicineRepository.getTransactions(
        limit: 100,
      );
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  List<MedicineModel> get filteredMedicines {
    if (searchQuery.value.isEmpty) return medicines;
    final query = searchQuery.value.toLowerCase();
    return medicines.where((m) {
      return m.name.toLowerCase().contains(query) ||
          m.code.toLowerCase().contains(query) ||
          (m.supplier?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<MedicineModel> get lowStockMedicines {
    return medicines.where((m) => m.isLowStock).toList();
  }

  List<MedicineModel> get expiringSoonMedicines {
    return medicines.where((m) => m.isExpiringSoon && !m.isExpired).toList();
  }

  List<MedicineModel> get expiredMedicines {
    return medicines.where((m) => m.isExpired).toList();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    currentPage.value = 0;
  }

  void setViewTab(int tab) {
    viewTab.value = tab;
  }

  // Form operations
  void resetForm() {
    editingMedicine.value = null;
    codeController.clear();
    nameController.clear();
    unitController.clear();
    avgPriceController.clear();
    stockController.clear();
    minStockController.clear();
    lotNumberController.clear();
    supplierController.clear();
    expiryDate.value = null;
  }

  void setupFormForEdit(MedicineModel medicine) {
    editingMedicine.value = medicine;
    codeController.text = medicine.code;
    nameController.text = medicine.name;
    unitController.text = medicine.unit ?? '';
    avgPriceController.text = medicine.avgPrice.toString();
    stockController.text = medicine.stock.toString();
    minStockController.text = medicine.minStock?.toString() ?? '';
    lotNumberController.text = medicine.lotNumber ?? '';
    supplierController.text = medicine.supplier ?? '';
    expiryDate.value = medicine.expiryDate;
  }

  Future<bool> saveMedicine() async {
    if (!formKey.currentState!.validate()) return false;

    isLoading.value = true;
    try {
      final medicine = MedicineModel(
        id: editingMedicine.value?.id ?? '',
        code: codeController.text.trim(),
        name: nameController.text.trim(),
        unit: unitController.text.trim().isEmpty
            ? null
            : unitController.text.trim(),
        avgPrice: double.tryParse(avgPriceController.text) ?? 0,
        stock: double.tryParse(stockController.text) ?? 0,
        minStock: double.tryParse(minStockController.text),
        lotNumber: lotNumberController.text.trim().isEmpty
            ? null
            : lotNumberController.text.trim(),
        supplier: supplierController.text.trim().isEmpty
            ? null
            : supplierController.text.trim(),
        expiryDate: expiryDate.value,
      );

      if (editingMedicine.value != null) {
        await _medicineRepository.update(medicine);
      } else {
        await _medicineRepository.create(medicine);
      }

      final isEditing = editingMedicine.value != null;

      // Close dialog and reset form first
      isLoading.value = false;
      Get.back();
      resetForm();

      // Show success message
      Get.snackbar(
        'Thanh cong',
        isEditing ? 'Da cap nhat thong tin thuoc' : 'Da them thuoc moi',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );

      // Reload medicines after dialog is closed
      await loadMedicines(refresh: true);
      return true;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Loi',
        'Khong the luu thuoc: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    }
  }

  Future<void> deleteMedicine(MedicineModel medicine) async {
    if (!PermissionService.to.can(AppPermission.pharmacyDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa thuốc',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xac nhan xoa'),
        content: Text('Ban co chac muon xoa thuoc "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xoa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _medicineRepository.delete(medicine.id);
        await loadMedicines(refresh: true);
        Get.snackbar(
          'Thanh cong',
          'Da xoa thuoc',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Loi',
          'Khong the xoa thuoc: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    }
  }

  // Transaction form operations
  void resetTransactionForm() {
    selectedMedicineId.value = '';
    transactionType.value = 'import';
    quantityController.clear();
    unitPriceController.clear();
    purposeController.clear();
    transNotesController.clear();
    transactionDate.value = DateTime.now();
  }

  Future<bool> saveTransaction() async {
    if (!transFormKey.currentState!.validate()) return false;

    if (selectedMedicineId.value.isEmpty) {
      Get.snackbar(
        'Loi',
        'Vui long chon thuoc',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return false;
    }

    isLoading.value = true;
    try {
      final transaction = MedicineTransactionModel(
        id: '',
        medicineId: selectedMedicineId.value,
        type: transactionType.value,
        quantity: double.tryParse(quantityController.text) ?? 0,
        unitPrice: double.tryParse(unitPriceController.text),
        purpose: purposeController.text.trim().isEmpty
            ? null
            : purposeController.text.trim(),
        notes: transNotesController.text.trim().isEmpty
            ? null
            : transNotesController.text.trim(),
        transactionDate: transactionDate.value ?? DateTime.now(),
      );

      await _medicineRepository.createTransaction(transaction);

      final isImport = transactionType.value == 'import';

      // Close dialog first
      isLoading.value = false;
      Get.back();
      resetTransactionForm();

      // Show success message
      Get.snackbar(
        'Thanh cong',
        isImport ? 'Da nhap kho' : 'Da xuat kho',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );

      // Reload after dialog is closed
      await loadMedicines(refresh: true);
      await loadTransactions();
      return true;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Loi',
        'Khong the luu giao dich: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    }
  }

  // Excel operations
  Future<void> importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        isLoading.value = true;
        final filePath = result.files.single.path;
        if (filePath == null) return;

        final imported = await _excelService.importMedicines(filePath);

        if (imported.isNotEmpty) {
          final count = await _excelService.saveMedicinesToDb(imported);
          await loadMedicines(refresh: true);
          Get.snackbar(
            'Thanh cong',
            'Da nhap $count thuoc tu Excel',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade100,
          );
        } else {
          Get.snackbar(
            'Thong bao',
            'Khong tim thay du lieu thuoc trong file',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.shade100,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the nhap file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportToExcel() async {
    if (medicines.isEmpty) {
      Get.snackbar(
        'Thong bao',
        'Danh sach trong',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    isLoading.value = true;
    try {
      await _excelService.exportMedicines(medicines);
    } finally {
      isLoading.value = false;
    }
  }

  // Statistics
  double get totalStockValue {
    return medicines.fold(0, (sum, m) => sum + m.stockValue);
  }

  int get totalMedicines => medicines.length;
  int get lowStockCount => lowStockMedicines.length;
  int get expiringSoonCount => expiringSoonMedicines.length;

  // Get medicine name by ID
  String getMedicineName(String id) {
    final medicine = medicines.firstWhereOrNull((m) => m.id == id);
    return medicine?.name ?? 'Khong ro';
  }

  // Format currency
  String formatCurrency(double value) {
    final formatter = NumberFormat('#,###', 'vi');
    return '${formatter.format(value)} VND';
  }
}
