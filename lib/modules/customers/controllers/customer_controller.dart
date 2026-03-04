import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../services/excel_service.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/pet_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/pet_repository.dart';

class CustomerController extends GetxController {
  final CustomerRepository _customerRepository = CustomerRepository();
  final PetRepository _petRepository = PetRepository();
  final ExcelService _excelService = Get.put(ExcelService());

  final isLoading = false.obs;
  final customers = <CustomerModel>[].obs;
  final searchQuery = ''.obs;

  // Detail view data
  final currentCustomer = Rxn<CustomerModel>();
  final customerPets = <PetModel>[].obs;

  // Form controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final editingCustomer = Rxn<CustomerModel>();

  // Pagination
  final int limit = 15;
  final currentPage = 1.obs;
  final totalPages = 1.obs;

  @override
  void onInit() {
    super.onInit();
    loadCustomers();

    // Auto-refresh when remote data changes via realtime sync
    if (Get.isRegistered<SyncEngine>()) {
      ever(Get.find<SyncEngine>().syncVersion, (_) {
        loadCustomers(refresh: true, background: true);
      });
    }

    // Debounce search query to avoid spamming the database
    debounce(
      searchQuery,
      (_) => loadCustomers(refresh: true),
      time: const Duration(milliseconds: 500),
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.onClose();
  }

  bool _isReloading = false;

  // Expanded List to include associated pets for UI rendering
  final customerPetsMap = <String, List<PetModel>>{}.obs;
  
  // Stats mapping for UI: customerId -> { 'caseCount': int, 'lastVisit': DateTime? }
  final customerStatsMap = <String, Map<String, dynamic>>{}.obs;

  Future<void> loadCustomers({bool refresh = false, bool background = false}) async {
    if (refresh) {
      if (_isReloading) return;
      _isReloading = true;
      currentPage.value = 1;
    } else if (isLoading.value) {
      return;
    }

    if (!background || customers.isEmpty) {
      isLoading.value = true;
    }

    try {
      final totalRecords = await _customerRepository.count(searchQuery.value);
      totalPages.value = (totalRecords / limit).ceil() == 0
          ? 1
          : (totalRecords / limit).ceil();

      final int offset = (currentPage.value - 1) * limit;

      List<CustomerModel> newItems;
      if (searchQuery.value.trim().isNotEmpty) {
        newItems = await _customerRepository.search(
          searchQuery.value,
          limit: limit,
          offset: offset,
        );
      } else {
        newItems = await _customerRepository.getAll(
          limit: limit,
          offset: offset,
        );
      }
      customers.value = newItems;
      
      // Load corresponding pets
      await _loadPetsForCustomers(newItems);
      
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách khách hàng: $e');
    } finally {
      if (!background || customers.isEmpty) {
        isLoading.value = false;
      }
      if (refresh) _isReloading = false;
    }
  }

  Future<void> _loadPetsForCustomers(List<CustomerModel> customerList) async {
    final db = await DatabaseProvider.instance.database;
    for (var customer in customerList) {
      // 1. Fetch pets
      final pets = await _petRepository.getByCustomerId(customer.id);
      customerPetsMap[customer.id] = pets;
      
      // 2. Fetch basic stats (total cases, last visit date)
      if (pets.isNotEmpty) {
        final petIds = pets.map((p) => p.id).toList();
        final placeholders = List.filled(petIds.length, '?').join(',');
        
        final statsResult = await db.rawQuery(
          '''
          SELECT 
            COUNT(id) as caseCount, 
            MAX(admission_date) as lastVisit
          FROM medical_cases 
          WHERE pet_id IN ($placeholders) 
            AND (_is_deleted IS NULL OR _is_deleted = 0)
          ''',
             petIds,
        );
        
        if (statsResult.isNotEmpty) {
          final row = statsResult.first;
          final count = row['caseCount'] as int? ?? 0;
          final lastVisitStr = row['lastVisit'] as String?;
          final lastVisit = lastVisitStr != null ? DateTime.tryParse(lastVisitStr) : null;
          
          customerStatsMap[customer.id] = {
            'caseCount': count,
            'lastVisit': lastVisit,
          };
        } else {
             customerStatsMap[customer.id] = {'caseCount': 0, 'lastVisit': null};
        }
      } else {
        customerStatsMap[customer.id] = {'caseCount': 0, 'lastVisit': null};
      }
    }
  }

  void goToPage(int page) {
    if (page < 1 || page > totalPages.value || page == currentPage.value)
      return;
    currentPage.value = page;
    loadCustomers();
  }

  // --- Export Feature ---
  Future<void> exportCustomers() async {
    isLoading.value = true;
    try {
      // Use ExcelService -> It handles fetching pets internally now.
      await _excelService.exportCustomers(customers);
    } catch (e) {
      Get.snackbar(
        'Lỗi Export',
        'Không thể xuất file: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadCustomerDetails(String customerId) async {
    isLoading.value = true;
    try {
      final customer = await _customerRepository.getById(customerId);
      if (customer != null) {
        currentCustomer.value = customer;
        customerPets.value = await _petRepository.getByCustomerId(customerId);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải chi tiết khách hàng: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Form operations
  void resetForm() {
    editingCustomer.value = null;
    nameController.clear();
    phoneController.clear();
    addressController.clear();
  }

  void setupFormForEdit(CustomerModel customer) {
    editingCustomer.value = customer;
    nameController.text = customer.name;
    phoneController.text = customer.phone;
    addressController.text = customer.address ?? '';
  }

  Future<bool> saveCustomer() async {
    if (!formKey.currentState!.validate()) return false;

    isLoading.value = true;
    try {
      final customer = CustomerModel(
        id: editingCustomer.value?.id ?? '',
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
      );

      if (editingCustomer.value != null) {
        await _customerRepository.update(customer);

        // Update current detail view if needed
        if (currentCustomer.value?.id == customer.id) {
          currentCustomer.value = customer;
        }

        Get.snackbar(
          'Thành công',
          'Đã cập nhật thông tin khách hàng',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        await _customerRepository.create(customer);
        Get.snackbar(
          'Thành công',
          'Đã thêm khách hàng mới',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }

      await loadCustomers(refresh: true);
      return true;
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể lưu thông tin: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Pet creation form within Customer Detail
  final petFormKey = GlobalKey<FormState>();
  final petNameController = TextEditingController();
  final petSpecies = ''.obs;
  final petBreedController = TextEditingController();
  final petBirthOrAgeController = TextEditingController();
  final petWeightController = TextEditingController();
  final petGender = ''.obs;
  final petColorController = TextEditingController();
  final petIsNeutered = false.obs;
  final petHealthNotesController = TextEditingController();

  void resetPetForm() {
    petNameController.clear();
    petSpecies.value = 'Chó'; // Default
    petBreedController.clear();
    petBirthOrAgeController.clear();
    petWeightController.clear();
    petGender.value = 'Đực'; // Default
    petColorController.clear();
    petIsNeutered.value = false;
    petHealthNotesController.clear();
  }

  void setupFormForPetEdit(PetModel pet) {
    petNameController.text = pet.name;
    petSpecies.value = pet.species.isNotEmpty ? pet.species : 'Chó';
    petBreedController.text = pet.breed ?? '';
    petBirthOrAgeController.text = pet.ageInputValue;
    petWeightController.text = pet.weight?.toString() ?? '';
    petGender.value = pet.gender ?? 'Đực';
    petColorController.text = ''; // Add later if db schema updates
    petIsNeutered.value = false;
    petHealthNotesController.text = pet.notes ?? '';
  }

  Future<void> addPetToCustomer(String customerId) async {
    if (petNameController.text.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Vui lòng nhập tên thú cưng',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    isLoading.value = true;
    try {
      final pet = PetModel(
        id: '',
        customerId: customerId,
        name: petNameController.text.trim(),
        species: petSpecies.value,
        breed: petBreedController.text.trim().isEmpty
            ? null
            : petBreedController.text.trim(),
        age: int.tryParse(petBirthOrAgeController.text),
        gender: petGender.value,
        weight: double.tryParse(petWeightController.text),
        notes: petHealthNotesController.text.trim().isEmpty
            ? null
            : petHealthNotesController.text.trim(),
      );

      await _petRepository.create(pet);

      // Refresh list
      customerPets.value = await _petRepository.getByCustomerId(customerId);

      Get.back(); // Close dialog
      Get.snackbar(
        'Thành công',
        'Đã thêm thú cưng mới',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể thêm thú cưng: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Pet history
  final petHistory = <Map<String, dynamic>>[].obs;
  final isHistoryLoading = false.obs;

  Future<void> loadPetHistory(String petId) async {
    isHistoryLoading.value = true;
    try {
      final db = await DatabaseProvider.instance.database;
      final history = await db.query(
        'medical_cases',
        where: 'pet_id = ?',
        whereArgs: [petId],
        orderBy: 'admission_date DESC',
      );
      petHistory.value = history;
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải lịch sử bệnh án: $e');
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> deleteMedicalCase(String caseId, String petId) async {
    if (!PermissionService.to.can(AppPermission.casesDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa bệnh án',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc muốn xóa bệnh án này? Hành động không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await DatabaseProvider.instance.database;
        final now = DateTime.now().toUtc().toIso8601String();

        // Get case_services IDs for sync tracking
        final serviceRows = await db.query(
          'case_services',
          columns: ['id'],
          where: 'case_id = ?',
          whereArgs: [caseId],
        );

        // Soft delete (needed for sync to propagate deletion to cloud)
        await db.update(
          'medical_cases',
          {'_is_deleted': 1, 'updated_at': now, '_sync_status': 'pending'},
          where: 'id = ?',
          whereArgs: [caseId],
        );
        await db.update(
          'case_services',
          {'_is_deleted': 1, 'updated_at': now, '_sync_status': 'pending'},
          where: 'case_id = ?',
          whereArgs: [caseId],
        );

        // Track changes for sync
        if (Get.isRegistered<SyncEngine>()) {
          final engine = SyncEngine.to;
          await engine.trackChange(
            table: 'medical_cases',
            recordId: caseId,
            operation: ChangeOperation.delete,
          );
          for (final row in serviceRows) {
            await engine.trackChange(
              table: 'case_services',
              recordId: row['id'] as String,
              operation: ChangeOperation.delete,
            );
          }
        }

        // Reload history
        loadPetHistory(petId);
        Get.snackbar(
          'Thành công',
          'Đã xóa bệnh án',
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Lỗi',
          'Không thể xóa bệnh án: $e',
          backgroundColor: Colors.red.shade100,
        );
      }
    }
  }

  Future<void> deleteCustomer(CustomerModel customer) async {
    if (!PermissionService.to.can(AppPermission.customersDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa khách hàng',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa khách hàng "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _customerRepository.delete(customer.id);
        await loadCustomers(refresh: true);
        Get.back(); // Close detail view if open
        Get.snackbar(
          'Thành công',
          'Đã xóa khách hàng',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Lỗi',
          'Không thể xóa khách hàng: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    }
  }

  List<CustomerModel> get filteredCustomers {
    return customers;
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  // --- Import Feature ---
  Future<void> importCustomers() async {
    try {
      // 1. Pick File
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      isLoading.value = true;
      final filePath = result.files.single.path!;

      // Delegate parsing to ExcelService
      final importedData = await _excelService.importCustomersWithPets(
        filePath,
      );
      if (importedData.isEmpty) {
        isLoading.value = false;
        return;
      }

      int successCount = 0;
      int updatedCount = 0;

      for (final item in importedData) {
        final customer = item.customer;
        final pet = item.pet;

        // Check if customer exists
        CustomerModel? targetCustomer;
        final existingCustomers = await _customerRepository.search(
          customer.phone,
        );

        if (existingCustomers.isNotEmpty) {
          targetCustomer = existingCustomers.first;
          updatedCount++;
        } else {
          // Create New Customer
          await _customerRepository.create(customer);
          targetCustomer = customer;
          successCount++;
        }

        // Add Pet if info exists
        if (targetCustomer != null && pet != null) {
          final newPet = PetModel(
            id: pet.id, // ExcelService generated this
            customerId: targetCustomer.id, // Link to actual customer ID
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            age: pet.age,
            gender: pet.gender,
            weight: pet.weight,
            notes: 'Imported',
          );
          await _petRepository.create(newPet);
        }
      }

      await loadCustomers(refresh: true);
      Get.defaultDialog(
        title: 'Nhập dữ liệu thành công',
        middleText:
            'Đã xử lý ${importedData.length} dòng.\\nThêm mới: $successCount khách.\\nCập nhật/Chi tiết: $updatedCount khách.',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } catch (e) {
      Get.defaultDialog(
        title: 'Lỗi Import',
        middleText: 'Có lỗi xảy ra: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
      print('Import Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // --- Template Feature ---
  Future<void> downloadTemplate() async {
    isLoading.value = true;
    try {
      await _excelService.generateCustomerTemplate();
    } catch (e) {
      Get.snackbar(
        'Lỗi Tải Mẫu',
        'Không thể tạo file mẫu: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
