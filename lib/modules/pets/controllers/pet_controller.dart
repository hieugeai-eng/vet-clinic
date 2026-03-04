import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/pet_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/customer_repository.dart';

class PetController extends GetxController {
  final PetRepository _petRepository = PetRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  final isLoading = false.obs;
  final pets = <PetModel>[].obs;
  final customers = <CustomerModel>[].obs;
  final searchQuery = ''.obs;
  final selectedSpecies = ''.obs;

  // Pagination
  final int limit = 15;
  final currentPage = 1.obs;
  final totalPages = 1.obs;

  // Form controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final ageUnit = 'Tháng'.obs;
  final weightController = TextEditingController();
  final notesController = TextEditingController();

  final selectedCustomerId = ''.obs;
  final selectedGender = ''.obs;
  final formSpecies = ''.obs;
  final breedController = TextEditingController();

  // Current editing pet
  final editingPet = Rxn<PetModel>();

  // Gender options
  final genderList = <String>['Duc', 'Đực', 'Male', 'Cai', 'Cái', 'Female'].obs;

  // Species options
  final speciesList = [
    'Cho',
    'Chó',
    'Meo',
    'Mèo',
    'Tho',
    'Thỏ',
    'Hamster',
    'Chim',
    'Bo sat',
    'Bò sát',
    'Khac',
    'Khác',
  ];

  @override
  void onInit() {
    super.onInit();
    debounce(
      searchQuery,
      (_) => loadPets(refresh: true),
      time: const Duration(milliseconds: 500),
    );
  }

  @override
  void onReady() {
    super.onReady();
    loadPets();
    loadCustomers();
  }

  @override
  void onClose() {
    nameController.dispose();
    ageController.dispose();
    weightController.dispose();
    notesController.dispose();
    breedController.dispose();
    super.onClose();
  }

  bool _isReloading = false;

  Future<void> loadPets({bool refresh = false}) async {
    if (refresh) {
      if (_isReloading) return;
      _isReloading = true;
      currentPage.value = 1;
    } else if (isLoading.value) {
      return;
    }

    isLoading.value = true;

    try {
      final totalRecords = await _petRepository.count(searchQuery.value);
      totalPages.value = (totalRecords / limit).ceil() == 0
          ? 1
          : (totalRecords / limit).ceil();

      final int offset = (currentPage.value - 1) * limit;

      if (searchQuery.value.trim().isNotEmpty) {
        final newItems = await _petRepository.search(
          searchQuery.value,
          limit: limit,
          offset: offset,
        );
        pets.value = newItems;
      } else {
        final newItems = await _petRepository.getAll(
          limit: limit,
          offset: offset,
        );
        pets.value = newItems;
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể tải danh sách thú cưng: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
      if (refresh) _isReloading = false;
    }
  }

  void goToPage(int page) {
    if (page < 1 || page > totalPages.value || page == currentPage.value)
      return;
    currentPage.value = page;
    loadPets();
  }

  Future<void> loadCustomers() async {
    try {
      customers.value = await _customerRepository.getAll();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }
  }

  List<PetModel> get filteredPets {
    var result = pets.toList();

    // Filter by species
    if (selectedSpecies.value.isNotEmpty) {
      result = result
          .where(
            (p) =>
                p.species.toLowerCase() == selectedSpecies.value.toLowerCase(),
          )
          .toList();
    }

    return result;
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void setSpeciesFilter(String species) {
    selectedSpecies.value = species;
  }

  void clearFilters() {
    searchQuery.value = '';
    selectedSpecies.value = '';
  }

  // Get customer name by ID
  String getCustomerName(String customerId) {
    final customer = customers.firstWhereOrNull((c) => c.id == customerId);
    return customer?.name ?? 'Khong ro';
  }

  // Get customer phone by ID
  String getCustomerPhone(String customerId) {
    final customer = customers.firstWhereOrNull((c) => c.id == customerId);
    return customer?.phone ?? '';
  }

  // Form operations
  void resetForm() {
    editingPet.value = null;
    nameController.clear();
    ageController.clear();
    ageUnit.value = 'Tháng';
    weightController.clear();
    notesController.clear();
    breedController.clear();
    selectedCustomerId.value = '';
    selectedGender.value = '';
    formSpecies.value = '';
  }

  void setupFormForEdit(PetModel pet) {
    editingPet.value = pet;
    nameController.text = pet.name;
    ageController.text = pet.ageInputValue;
    ageUnit.value = pet.ageInputUnit == 'năm' ? 'Năm' : 'Tháng';
    weightController.text = pet.weight?.toString() ?? '';
    notesController.text = pet.notes ?? '';
    breedController.text = pet.breed ?? '';
    selectedCustomerId.value = pet.customerId;

    // Handle Gender
    final gender = pet.gender ?? '';
    if (gender.isNotEmpty && !genderList.contains(gender)) {
      genderList.add(gender);
    }
    selectedGender.value = gender;

    // Ensure species is in the list
    if (speciesList.contains(pet.species)) {
      formSpecies.value = pet.species;
    } else {
      // If species is not in list, add it temporarily or default to 'Khac'
      // Ideally we should add it to list to allow editing without changing it
      if (pet.species.isNotEmpty) {
        if (!speciesList.contains(pet.species)) {
          speciesList.add(pet.species);
        }
        formSpecies.value = pet.species;
      } else {
        formSpecies.value = speciesList.first;
      }
    }
  }

  Future<bool> savePet() async {
    if (!formKey.currentState!.validate()) return false;

    if (selectedCustomerId.value.isEmpty) {
      Get.snackbar(
        'Loi',
        'Vui long chon chu so huu',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return false;
    }

    if (formSpecies.value.isEmpty) {
      Get.snackbar(
        'Loi',
        'Vui long chon loai thu cung',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return false;
    }

    isLoading.value = true;
    try {
      int? ageValue = int.tryParse(ageController.text);
      String? computedDob;
      if (ageValue != null) {
        final now = DateTime.now();
        if (ageUnit.value == 'Năm') {
          computedDob = DateTime(
            now.year - ageValue,
            now.month,
            now.day,
          ).toIso8601String();
        } else {
          int birthMonth = now.month - ageValue;
          int birthYear = now.year;
          while (birthMonth <= 0) {
            birthMonth += 12;
            birthYear--;
          }
          computedDob = DateTime(birthYear, birthMonth, 1).toIso8601String();
        }
      }

      final pet = PetModel(
        id: editingPet.value?.id ?? '',
        customerId: selectedCustomerId.value,
        name: nameController.text.trim(),
        species: formSpecies.value,
        breed: breedController.text.trim().isEmpty
            ? null
            : breedController.text.trim(),
        dateOfBirth: computedDob,
        age: ageValue,
        gender: selectedGender.value.isEmpty ? null : selectedGender.value,
        weight: double.tryParse(weightController.text),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );

      if (editingPet.value != null) {
        await _petRepository.update(pet);
        Get.snackbar(
          'Thanh cong',
          'Da cap nhat thong tin thu cung',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        await _petRepository.create(pet);
        Get.snackbar(
          'Thanh cong',
          'Da them thu cung moi',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }

      await loadPets(refresh: true);
      return true;
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the luu thong tin: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deletePet(PetModel pet) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xac nhan xoa'),
        content: Text('Ban co chac muon xoa thu cung "${pet.name}"?'),
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
        await _petRepository.delete(pet.id);
        await loadPets(refresh: true);
        Get.snackbar(
          'Thanh cong',
          'Da xoa thu cung',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Loi',
          'Khong the xoa thu cung: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    }
  }

  // Statistics
  Map<String, int> get speciesStats {
    final stats = <String, int>{};
    for (final pet in pets) {
      stats[pet.species] = (stats[pet.species] ?? 0) + 1;
    }
    return stats;
  }

  int get totalPets => pets.length;
}
