import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/sync/sync_engine.dart';

import '../../../data/models/customer_model.dart';
import '../../../data/models/medicine_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../services/excel_service.dart';
import '../../customers/controllers/customer_controller.dart';
import '../../pets/controllers/pet_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../petshop/controllers/petshop_controller.dart';
import '../../pharmacy/controllers/pharmacy_controller.dart';
import '../../settings/submodules/services/controllers/service_controller.dart';

/// Data category for import/export
enum DataCategory {
  customers('Khách hàng & Thú cưng', Icons.people_alt_rounded),
  medicines('Kho thuốc', Icons.medication_rounded),
  products('Sản phẩm Petshop', Icons.shopping_bag_rounded),
  services('Dịch vụ', Icons.medical_services_rounded);

  final String label;
  final IconData icon;
  const DataCategory(this.label, this.icon);
}

class LibraryController extends GetxController {
  final ExcelService _excelService = Get.find<ExcelService>();
  final CustomerRepository _customerRepository = CustomerRepository();
  final PetRepository _petRepository = PetRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();
  final ProductRepository _productRepository = ProductRepository();

  final isLoading = false.obs;
  final selectedCategory = DataCategory.customers.obs;
  final recentActivities = <String>[].obs;
  final counts = <DataCategory, int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadCounts();

    // Auto-refresh counts when remote data changes via realtime sync
    if (Get.isRegistered<SyncEngine>()) {
      ever(Get.find<SyncEngine>().syncVersion, (_) {
        loadCounts();
      });
    }
  }

  Future<void> loadCounts() async {
    try {
      final clinicId = Get.isRegistered<AuthService>()
          ? AuthService.to.currentProfile.value?.clinicId
          : null;
      debugPrint('[LibraryCounts] clinicId=$clinicId');

      // Auto-fix orphaned records with wrong/missing clinic_id
      if (clinicId != null) {
        final db = await DatabaseProvider.instance.database;
        for (final table in [
          'customers',
          'pets',
          'medicines',
          'products',
          'services',
          'staff',
        ]) {
          await db.rawUpdate(
            'UPDATE $table SET clinic_id = ? WHERE clinic_id IS NULL OR clinic_id != ?',
            [clinicId, clinicId],
          );
        }
      }

      // Customers
      final cCount = await _customerRepository.count();
      counts[DataCategory.customers] = cCount;
      debugPrint('[LibraryCounts] customers=$cCount');

      // Medicines
      final mCount = await _medicineRepository.count();
      counts[DataCategory.medicines] = mCount;
      debugPrint('[LibraryCounts] medicines=$mCount');

      // Products
      final pCount = await _productRepository.count();
      counts[DataCategory.products] = pCount;
      debugPrint('[LibraryCounts] products=$pCount');

      // Services
      final db = await DatabaseProvider.instance.database;
      final clinicFilter = clinicId != null
          ? "AND clinic_id = '$clinicId'"
          : '';
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM services WHERE (is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0) $clinicFilter',
      );
      final sCount = result.first['count'] as int? ?? 0;
      counts[DataCategory.services] = sCount;
      debugPrint('[LibraryCounts] services=$sCount');

      // Extra debug: raw count without filters
      final rawCustomers = await db.rawQuery(
        'SELECT COUNT(*) as c FROM customers',
      );
      debugPrint(
        '[LibraryCounts] raw customers (no filter)=${rawCustomers.first['c']}',
      );

      // Deep debug: check each filter
      final byClinic = await db.rawQuery(
        'SELECT clinic_id, COUNT(*) as c FROM customers GROUP BY clinic_id',
      );
      debugPrint('[LibraryCounts] customers by clinic_id: $byClinic');
      final byActive = await db.rawQuery(
        'SELECT is_active, COUNT(*) as c FROM customers GROUP BY is_active',
      );
      debugPrint('[LibraryCounts] customers by is_active: $byActive');
      final byDeleted = await db.rawQuery(
        'SELECT _is_deleted, COUNT(*) as c FROM customers GROUP BY _is_deleted',
      );
      debugPrint('[LibraryCounts] customers by _is_deleted: $byDeleted');
    } catch (e) {
      debugPrint('[LibraryCounts] ERROR: $e');
    }
  }

  /// Sync data to Cloud
  Future<void> syncData() async {
    if (Get.isRegistered<SyncEngine>()) {
      final syncEngine = Get.find<SyncEngine>();
      await syncEngine.syncAll();
      Get.snackbar(
        'Sync',
        'Đồng bộ hoàn tất',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Import data based on selected category
  Future<void> importData(DataCategory category) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) return;

      isLoading.value = true;
      final filePath = result.files.single.path!;
      int count = 0;

      switch (category) {
        case DataCategory.customers:
          {
            final imported = await _excelService.importCustomersWithPets(
              filePath,
            );
            debugPrint(
              '[LibraryImport] Parsed ${imported.length} customer/pet items from Excel',
            );
            if (imported.isNotEmpty) {
              int successCount = 0;
              int updatedCount = 0;
              int errorCount = 0;

              for (final item in imported) {
                try {
                  final customer = item.customer;
                  final pet = item.pet;

                  CustomerModel? targetCustomer;

                  // 1. Check if customer exists by phone (Exact match)
                  final existing = await _customerRepository.getByPhone(
                    customer.phone,
                  );

                  if (existing != null) {
                    // Update existing
                    final old = existing;
                    targetCustomer = customer.copyWith(
                      id: old.id,
                      createdAt: old.createdAt,
                      updatedAt: DateTime.now(),
                    );
                    await _customerRepository.update(targetCustomer);
                    updatedCount++;
                    debugPrint(
                      '[LibraryImport] Updated customer: ${customer.name} (${customer.phone})',
                    );
                  } else {
                    // Create new
                    targetCustomer = await _customerRepository.create(customer);
                    successCount++;
                    debugPrint(
                      '[LibraryImport] Created customer: ${customer.name} (${customer.phone}) => id: ${targetCustomer.id}',
                    );
                  }

                  // 2. Save Pet with Correct Link (check duplicates first)
                  if (pet != null && targetCustomer != null) {
                    // Check if pet with same name already exists for this customer
                    final existingPets = await _petRepository.getByCustomerId(
                      targetCustomer.id,
                    );
                    final petNameLower = pet.name.trim().toLowerCase();
                    final duplicate = existingPets.any(
                      (p) => p.name.trim().toLowerCase() == petNameLower,
                    );

                    if (!duplicate) {
                      final petToSave = pet.copyWith(
                        customerId: targetCustomer.id,
                      );
                      await _petRepository.create(petToSave);
                      debugPrint(
                        '[LibraryImport] Created pet: ${pet.name} for customer ${targetCustomer.id}',
                      );
                    } else {
                      debugPrint(
                        '[LibraryImport] Skipped duplicate pet: ${pet.name} for customer ${targetCustomer.id}',
                      );
                    }
                  }
                } catch (e) {
                  errorCount++;
                  debugPrint(
                    '[LibraryImport] ERROR saving ${item.customer.name}: $e',
                  );
                }
              }

              count = successCount + updatedCount;
              debugPrint(
                '[LibraryImport] Result: $successCount new, $updatedCount updated, $errorCount errors',
              );

              // Fix-up: force set clinic_id and is_active on ALL customers/pets
              // This bypasses any ORM issues and ensures data is queryable
              final clinicId = Get.isRegistered<AuthService>()
                  ? AuthService.to.currentProfile.value?.clinicId
                  : null;
              if (clinicId != null) {
                final db = await DatabaseProvider.instance.database;

                // Fix customers without correct clinic_id (NULL or mismatched)
                final fixedCustomers = await db.rawUpdate(
                  'UPDATE customers SET clinic_id = ? WHERE clinic_id IS NULL OR clinic_id != ?',
                  [clinicId, clinicId],
                );
                debugPrint(
                  '[LibraryImport] Fixed $fixedCustomers customers with wrong/missing clinic_id',
                );

                // Fix customers without is_active
                final fixedActive = await db.rawUpdate(
                  'UPDATE customers SET is_active = 1 WHERE is_active IS NULL OR is_active = 0',
                );
                debugPrint(
                  '[LibraryImport] Fixed $fixedActive customers with missing is_active',
                );

                // Fix pets without correct clinic_id
                final fixedPets = await db.rawUpdate(
                  'UPDATE pets SET clinic_id = ? WHERE clinic_id IS NULL OR clinic_id != ?',
                  [clinicId, clinicId],
                );
                debugPrint(
                  '[LibraryImport] Fixed $fixedPets pets with missing clinic_id',
                );

                // Verify: count with raw SQL
                final rawTotal = await db.rawQuery(
                  'SELECT COUNT(*) as c FROM customers',
                );
                final filteredTotal = await db.rawQuery(
                  'SELECT COUNT(*) as c FROM customers WHERE clinic_id = ? AND (is_active IS NULL OR is_active = 1)',
                  [clinicId],
                );
                debugPrint(
                  '[LibraryImport] Verify: total=${rawTotal.first['c']}, filtered=${filteredTotal.first['c']}',
                );

                // Cleanup: remove duplicate pets (same name + customer_id), keep oldest
                final duplicateCount = await db.rawDelete('''
                  DELETE FROM pets WHERE id NOT IN (
                    SELECT MIN(id) FROM pets 
                    GROUP BY customer_id, LOWER(TRIM(name))
                  )
                ''');
                if (duplicateCount > 0) {
                  debugPrint(
                    '[LibraryImport] Cleaned up $duplicateCount duplicate pets',
                  );
                }
              }

              // Force refresh customer/pet controllers if registered
              if (Get.isRegistered<CustomerController>()) {
                Get.find<CustomerController>().loadCustomers(refresh: true);
              }
              if (Get.isRegistered<PetController>()) {
                Get.find<PetController>().loadPets(refresh: true);
              }
            }
          }
          break;

        case DataCategory.medicines:
          {
            final imported = await _excelService.importMedicines(filePath);
            if (imported.isNotEmpty) {
              count = await _excelService.saveMedicinesToDb(imported);
              // Fix-up: ensure clinic_id and is_active
              final cid = Get.isRegistered<AuthService>()
                  ? AuthService.to.currentProfile.value?.clinicId
                  : null;
              if (cid != null) {
                final db = await DatabaseProvider.instance.database;
                await db.rawUpdate(
                  'UPDATE medicines SET clinic_id = ? WHERE clinic_id IS NULL',
                  [cid],
                );
                await db.rawUpdate(
                  'UPDATE medicines SET is_active = 1 WHERE is_active IS NULL OR is_active = 0',
                );
              }
              if (Get.isRegistered<PharmacyController>()) {
                Get.find<PharmacyController>().loadMedicines(refresh: true);
              }
            }
          }
          break;

        case DataCategory.products:
          {
            final imported = await _excelService.importProducts(filePath);
            if (imported.isNotEmpty) {
              count = await _excelService.saveProductsToDb(imported);
              // Fix-up: ensure clinic_id and is_active
              final cid = Get.isRegistered<AuthService>()
                  ? AuthService.to.currentProfile.value?.clinicId
                  : null;
              if (cid != null) {
                final db = await DatabaseProvider.instance.database;
                await db.rawUpdate(
                  'UPDATE products SET clinic_id = ? WHERE clinic_id IS NULL',
                  [cid],
                );
                await db.rawUpdate(
                  'UPDATE products SET is_active = 1 WHERE is_active IS NULL OR is_active = 0',
                );
              }
              if (Get.isRegistered<PetshopController>()) {
                Get.find<PetshopController>().loadProducts(refresh: true);
              }
            }
          }
          break;

        case DataCategory.services:
          {
            final imported = await _excelService.importServices(filePath);
            if (imported.isNotEmpty) {
              count = await _excelService.saveServicesToDb(imported);
              // Fix-up: ensure clinic_id and is_active
              final cid = Get.isRegistered<AuthService>()
                  ? AuthService.to.currentProfile.value?.clinicId
                  : null;
              if (cid != null) {
                final db = await DatabaseProvider.instance.database;
                await db.rawUpdate(
                  'UPDATE services SET clinic_id = ? WHERE clinic_id IS NULL',
                  [cid],
                );
                await db.rawUpdate(
                  'UPDATE services SET is_active = 1 WHERE is_active IS NULL OR is_active = 0',
                );
              }
              if (Get.isRegistered<ServiceController>()) {
                Get.find<ServiceController>().loadServices();
              }
            }
          }
          break;
      }

      if (count > 0) {
        // Post-import verification: raw unfiltered debug query
        final db = await DatabaseProvider.instance.database;
        final rawCount = await db.rawQuery(
          'SELECT COUNT(*) as c FROM customers',
        );
        final rawClinic = await db.rawQuery(
          'SELECT clinic_id, COUNT(*) as c FROM customers GROUP BY clinic_id',
        );
        final rawActive = await db.rawQuery(
          'SELECT is_active, COUNT(*) as c FROM customers GROUP BY is_active',
        );
        debugPrint(
          '[LibraryImport] RAW customers total: ${rawCount.first['c']}',
        );
        debugPrint('[LibraryImport] RAW customers by clinic_id: $rawClinic');
        debugPrint('[LibraryImport] RAW customers by is_active: $rawActive');
        final filteredCount = await _customerRepository.count();
        debugPrint(
          '[LibraryImport] Filtered count (via count()): $filteredCount',
        );

        _addActivity('Đã nhập $count ${category.label.toLowerCase()}');
        Get.snackbar(
          'Thành công',
          'Đã nhập $count ${category.label.toLowerCase()} — đang đồng bộ lên cloud...',
          backgroundColor: Colors.green.shade100,
          snackPosition: SnackPosition.BOTTOM,
        );
        // Trigger sync to push imported data to cloud
        if (Get.isRegistered<SyncEngine>()) {
          Get.find<SyncEngine>().syncAll();
        }
        // Refresh home dashboard counts
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().refresh();
        }
      } else {
        Get.snackbar(
          'Thông báo',
          'Không tìm thấy dữ liệu hợp lệ trong file',
          backgroundColor: Colors.orange.shade100,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể nhập file: $e',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
      await loadCounts();
      counts.refresh(); // Force RxMap to notify listeners
    }
  }

  /// Export data based on selected category
  Future<void> exportData(DataCategory category) async {
    isLoading.value = true;
    try {
      String? path;
      final db = await DatabaseProvider.instance.database;

      switch (category) {
        case DataCategory.customers:
          final clinicId = Get.isRegistered<AuthService>()
              ? AuthService.to.currentProfile.value?.clinicId
              : null;
          final cWhere = clinicId != null
              ? '(is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0) AND clinic_id = ?'
              : '(is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0)';
          final results = await db.query(
            'customers',
            where: cWhere,
            whereArgs: clinicId != null ? [clinicId] : null,
          );
          final customers = results
              .map((e) => CustomerModel.fromJson(e))
              .toList();
          if (customers.isEmpty) {
            _showEmptyWarning();
            return;
          }
          path = await _excelService.exportCustomers(customers);
          break;

        case DataCategory.medicines:
          final results = await db.query('medicines', where: 'is_active = 1');
          final medicines = results
              .map((e) => MedicineModel.fromJson(e))
              .toList();
          if (medicines.isEmpty) {
            _showEmptyWarning();
            return;
          }
          path = await _excelService.exportMedicines(medicines);
          break;

        case DataCategory.products:
          final results = await db.query('products', where: 'is_active = 1');
          final products = results
              .map((e) => ProductModel.fromJson(e))
              .toList();
          if (products.isEmpty) {
            _showEmptyWarning();
            return;
          }
          path = await _excelService.exportProducts(products);
          break;

        case DataCategory.services:
          final sClinicId = Get.isRegistered<AuthService>()
              ? AuthService.to.currentProfile.value?.clinicId
              : null;
          final sWhere = sClinicId != null
              ? '(is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0) AND clinic_id = ?'
              : '(is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0)';
          final results = await db.query(
            'services',
            where: sWhere,
            whereArgs: sClinicId != null ? [sClinicId] : null,
          );
          final services = results
              .map((e) => ServiceModel.fromJson(e))
              .toList();
          if (services.isEmpty) {
            _showEmptyWarning();
            return;
          }
          path = await _excelService.exportServices(services);
          break;
      }

      if (path != null) {
        _addActivity('Đã xuất ${category.label.toLowerCase()} → $path');
        Get.snackbar(
          'Thành công',
          'Đã xuất file: $path',
          backgroundColor: Colors.green.shade100,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể xuất file: $e',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Download Empty Template
  Future<void> downloadTemplate(DataCategory category) async {
    isLoading.value = true;
    try {
      String? path;
      switch (category) {
        case DataCategory.customers:
          path = await _excelService.generateCustomerTemplate();
          break;
        case DataCategory.medicines:
          path = await _excelService.generateMedicineTemplate();
          break;
        case DataCategory.products:
          path = await _excelService.generateProductTemplate();
          break;
        case DataCategory.services:
          path = await _excelService.generateServiceTemplate();
          break;
      }

      if (path != null) {
        _addActivity('Đã tạo mẫu ${category.label.toLowerCase()}');
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể tạo file mẫu: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _showEmptyWarning() {
    Get.snackbar(
      'Thông báo',
      'Danh sách trống, không có gì để xuất',
      backgroundColor: Colors.orange.shade100,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _addActivity(String message) {
    final time = DateTime.now();
    final timeStr =
        '${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}';
    recentActivities.insert(0, '[$timeStr] $message');
    if (recentActivities.length > 10) {
      recentActivities.removeLast();
    }
  }

  void navigateToManage(DataCategory category) {
    switch (category) {
      case DataCategory.customers:
        Get.toNamed('/customers');
        break;
      case DataCategory.medicines:
        Get.toNamed('/pharmacy');
        break;
      case DataCategory.products:
        Get.toNamed('/petshop');
        break;
      case DataCategory.services:
        Get.toNamed('/settings');
        break;
    }
  }

  Future<void> deleteAllData(DataCategory category) async {
    Get.defaultDialog(
      title: 'Cảnh báo nguy hiểm',
      middleText:
          'Bạn có chắc chắn muốn XÓA VĨNH VIỄN toàn bộ dữ liệu ${category.label}?\n\nHành động này không thể hoàn tác!',
      textConfirm: 'Xóa tất cả',
      textCancel: 'Hủy bỏ',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: Colors.black87,
      onConfirm: () async {
        Get.back(); // Close dialog
        isLoading.value = true;
        try {
          switch (category) {
            case DataCategory.customers:
              await _customerRepository.deleteAll();
              if (Get.isRegistered<CustomerController>()) {
                Get.find<CustomerController>().loadCustomers(refresh: true);
              }
              break;
            case DataCategory.medicines:
              await _medicineRepository.deleteAll();
              if (Get.isRegistered<PharmacyController>()) {
                Get.find<PharmacyController>().loadMedicines(refresh: true);
              }
              break;
            case DataCategory.products:
              await _productRepository.deleteAll();
              if (Get.isRegistered<PetshopController>()) {
                Get.find<PetshopController>().loadProducts(refresh: true);
              }
              break;
            case DataCategory.services:
              final db = await DatabaseProvider.instance.database;
              await db.delete('services');
              if (Get.isRegistered<ServiceController>()) {
                Get.find<ServiceController>().loadServices();
              }
              break;
          }

          _addActivity('Đã xóa toàn bộ ${category.label.toLowerCase()}');
          loadCounts();

          Get.snackbar(
            'Đã xóa dữ liệu',
            'Toàn bộ ${category.label.toLowerCase()} đã được xóa sạch',
            backgroundColor: Colors.red.shade100,
            snackPosition: SnackPosition.BOTTOM,
          );
        } catch (e) {
          Get.snackbar(
            'Lỗi',
            'Không thể xóa dữ liệu: $e',
            backgroundColor: Colors.red.shade100,
            snackPosition: SnackPosition.BOTTOM,
          );
        } finally {
          isLoading.value = false;
        }
      },
    );
  }

  void openPermissionsConfig() {
    Get.snackbar(
      'Tính năng đang phát triển',
      'Cấu hình phân quyền sẽ được cập nhật trong phiên bản sau',
      backgroundColor: Colors.blue.shade100,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void selectCategory(DataCategory category) {
    selectedCategory.value = category;
  }
}
