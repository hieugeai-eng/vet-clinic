import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_colors.dart'; // Added

import '../../../data/models/customer_model.dart';
import '../../../data/models/pet_model.dart';
import '../../../data/models/medicine_model.dart'; // Added
import '../../../data/models/staff_model.dart';
import '../../../data/models/medical_case_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/product_model.dart'; // Added
import '../../../data/models/vital_signs_model.dart';
import '../../../data/models/case_log_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/product_repository.dart'; // Added
import '../../settings/submodules/staff/repositories/staff_repository.dart';
import '../../../core/services/staff_sync_helper.dart';
import '../../../routes/app_routes.dart';
import '../../../services/pdf_service.dart';
import '../../../services/return_service.dart'; // Added
import '../../../core/widgets/pdf_preview_view.dart';
import '../../hospitalization/repositories/cage_repository.dart'; // Added
import '../../../data/models/cage_model.dart'; // Added
import '../../../data/repositories/medical_case_repository.dart';
import '../../../data/repositories/case_attachment_repository.dart';
import '../../../core/services/attachment_service.dart';

/// Controller for multi-step case creation form
class CaseFormController extends GetxController {
  final uuid = const Uuid();
  final _medicineRepo = MedicineRepository();
  final _productRepo = ProductRepository(); // Added
  final _staffRepo = StaffRepository();
  final _cageRepo = CageRepository(); // Added
  final _pdfService = Get.find<PdfService>();

  // Form state
  final currentStep = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isEditing = false.obs;
  String? caseId;

  // Track which case session we've initialized for (by case ID or 'new')
  String? _lastInitSession;

  // Step 1: Basic info
  final caseCode = ''.obs;
  final selectedCustomer = Rxn<CustomerModel>();
  final selectedPet = Rxn<PetModel>();
  final customerPets = <PetModel>[].obs;
  final admissionDate = DateTime.now().obs;

  // Form controllers for Step 1
  final phoneController = TextEditingController();
  final customerNameController = TextEditingController();
  final addressController = TextEditingController();
  final petNameController = TextEditingController();
  final petAgeController = TextEditingController();
  final petAgeUnit = 'Tháng'.obs; // NEW: "Tháng" hoặc "Năm"
  final petBreedController = TextEditingController();
  final otherSpeciesController =
      TextEditingController(); // Controller cho loài khác
  final speciesRadioValue =
      AppKeys.dog.obs; // Để quản lý UI radio button: Chó, Mèo, Khác
  final petSpecies = AppKeys.dog.obs; // Giá trị thực tế để lưu
  final petGender = AppKeys.male.obs;

  // Step 2: Clinical exam
  final staffId = ''.obs; // Nhan vien tiep nhan/Bac si
  final visitReasons = <String>[].obs;
  final reasonNotes = ''.obs;
  final temperature = ''.obs;
  final weight = ''.obs;
  final vomitingCount = ''.obs;
  final stoolCondition = AppKeys.stoolNormal.obs;
  final mentalStatus = AppKeys.mentalAlert.obs;
  final bodyCondition = AppKeys.bodyNormal.obs;
  final skinMucosa = ''.obs; // Da/Niêm mạc
  final otherInfo = ''.obs;

  // Step 3: Diagnosis & Treatment
  final diagnosis = ''.obs;
  final treatmentPlan = ''.obs; // Added
  final prognosis = AppKeys.prognosisUncertain.obs;
  final selectedServices = <CaseServiceModel>[].obs;
  final availableServices = <ServiceModel>[].obs;
  final availableProducts = <ProductModel>[].obs; // Added
  final availableMedicines = <MedicineModel>[].obs;
  final availableStaff = <StaffModel>[].obs;
  final totalEstimate = 0.0.obs;

  // Payment
  final advancePayment = 0.0.obs; // The total accumulated advances
  final newAdvancePaymentInput = 0.0.obs; // Input field for new advances
  final advancePaymentController =
      TextEditingController(); // Controller for input field
  final advancePaymentMethod = AppKeys.cash.obs; // Method for the new advance
  final advancePaymentHistory =
      <AdvancePaymentRecord>[].obs; // Lịch sử ứng tiền

  final remainingPaymentMethod = AppKeys.cash.obs; // New: Selected in UI
  final paymentMethod =
      AppKeys.cash.obs; // Final/Settlement method (stored in DB)
  final customerSignature = Rxn<String>();
  final clinicSignature = Rxn<String>();
  final agreeTreatment = false.obs;
  final agreeNoComplaint = false.obs;
  final notes = ''.obs;

  // Follow-up & Hospitalization
  final followUpDate = Rxn<DateTime>();
  final followUpNote = ''.obs; // New: Reason/Note for appointment
  final isHospitalized = false.obs;
  final cageNumber = ''.obs; // Now used for display or legacy
  final selectedCageId = ''.obs; // New
  final availableCages = <CageModel>[].obs; // New
  // final activeTab = 0.obs; // Removed in refactor

  // Visit reason options
  final visitReasonOptions = [
    AppKeys.vomit,
    AppKeys.weak,
    AppKeys.tired,
    AppKeys.accident,
    AppKeys.fever,
    AppKeys.diarrhea,
    AppKeys.nopet,
    AppKeys.breath,
    AppKeys.itch,
    AppKeys.other,
  ];

  @override
  void onInit() {
    super.onInit();
    isSaving.value = false;
    // Track session: case ID for edit, 'new' for new case
    final args = Get.arguments;
    _lastInitSession = args is MedicalCaseModel
        ? args.id
        : 'new_${DateTime.now().millisecondsSinceEpoch}';
    _initializeForm(args);
  }

  /// Reset all form fields and reload data for a new/edit case session.
  /// Only runs if Get.arguments changed (different case or new vs edit).
  /// This prevents data wipe when build() is called on widget rebuild.
  MedicalCaseModel? _initialCase;
  List<CaseServiceModel> _initialServices = [];

  final _isCompleted = false.obs;
  bool get isCompleted => _isCompleted.value;

  void reinitialize(dynamic routeArgs) {
    // Compute session ID: case ID for edit, 'new_timestamp' for new case
    final sessionId = routeArgs is MedicalCaseModel
        ? routeArgs.id
        : 'new_${DateTime.now().millisecondsSinceEpoch}';

    // Same case = same session (widget just rebuilt), skip reset
    if (sessionId == _lastInitSession) {
      print('[STAFF-DEBUG] reinitialize() SKIPPED - same session: $sessionId');
      return;
    }

    // Different case or genuinely new form, reset everything
    print(
      '[STAFF-DEBUG] reinitialize() RUNNING - new session: $sessionId (was: $_lastInitSession)',
    );
    _lastInitSession = sessionId;

    // Reset TextEditingControllers (clear, NOT dispose)
    phoneController.clear();
    customerNameController.clear();
    addressController.clear();
    petNameController.clear();
    petAgeController.clear();
    petAgeUnit.value = 'Tháng';
    petBreedController.clear();
    otherSpeciesController.clear();

    // Reset Rx fields
    currentStep.value = 0;
    isEditing.value = false;
    isSaving.value = false;
    _isCompleted.value = false;
    caseId = const Uuid().v4();
    caseCode.value = '';
    selectedCustomer.value = null;
    selectedPet.value = null;
    customerPets.clear();
    admissionDate.value = DateTime.now();
    speciesRadioValue.value = AppKeys.dog;
    petSpecies.value = AppKeys.dog;
    // petBreed.value = ''; // Removed as petBreedController is used
    // petAge.value = ''; // Removed as petAgeController is used
    petGender.value = AppKeys.male;
    staffId.value = '';
    visitReasons.clear();
    reasonNotes.value = '';
    temperature.value = '';
    weight.value = '';
    vomitingCount.value = '';
    stoolCondition.value = AppKeys.stoolNormal;
    mentalStatus.value = AppKeys.mentalAlert;
    bodyCondition.value = AppKeys.bodyNormal;
    skinMucosa.value = '';
    otherInfo.value = '';
    diagnosis.value = '';
    treatmentPlan.value = '';
    prognosis.value = AppKeys.prognosisUncertain;
    selectedServices.clear();
    totalEstimate.value = 0.0;
    advancePayment.value = 0.0;
    newAdvancePaymentInput.value = 0.0;
    advancePaymentMethod.value = AppKeys.cash;
    advancePaymentHistory.clear();
    remainingPaymentMethod.value = AppKeys.cash;
    paymentMethod.value = AppKeys.cash;
    customerSignature.value = null;
    clinicSignature.value = null;
    agreeTreatment.value = false;
    agreeNoComplaint.value = false;
    notes.value = '';
    followUpDate.value = null;
    followUpNote.value = '';
    isHospitalized.value = false;
    cageNumber.value = '';
    selectedCageId.value = '';

    // Reload form data (staff, services, case data from arguments)
    _initializeForm(routeArgs);
  }

  void forceReinitialize(dynamic routeArgs) {
    // Force a new session ID for new cases to bypass the skip check
    final sessionId = routeArgs is MedicalCaseModel
        ? routeArgs.id
        : 'new_${DateTime.now().millisecondsSinceEpoch}';
    _lastInitSession = null; // Ensure the skip check fails
    reinitialize(routeArgs);
  }

  @override
  void onClose() {
    phoneController.dispose();
    customerNameController.dispose();
    addressController.dispose();
    petNameController.dispose();
    otherSpeciesController.dispose();
    petAgeController.dispose();
    petBreedController.dispose();
    advancePaymentController.dispose();
    super.onClose();
  }

  // ... (keep existing code)

  /// Select existing pet
  void selectPet(PetModel pet) {
    selectedPet.value = pet;
    petNameController.text = pet.name;

    // Set species logic
    petSpecies.value = pet.species;
    if (pet.species == AppKeys.dog || pet.species == AppKeys.cat) {
      speciesRadioValue.value = pet.species;
      otherSpeciesController.clear();
    } else {
      speciesRadioValue.value = AppKeys.other;
      otherSpeciesController.text = pet.species;
    }

    petBreedController.text = pet.breed ?? '';
    petAgeController.text = pet.ageInputValue;
    petAgeUnit.value = pet.ageInputUnit == 'năm' ? 'Năm' : 'Tháng';
    // Normalize gender
    if (pet.gender == 'Đực') {
      petGender.value = AppKeys.male;
    } else if (pet.gender == 'Cái') {
      petGender.value = AppKeys.female;
    } else {
      petGender.value = pet.gender ?? AppKeys.male;
    }
  }

  Future<void> _initializeForm(dynamic args) async {
    isLoading.value = true;
    try {
      // Load medicines and services first
      final db = await DatabaseProvider.instance.database;
      final services = await db.query(
        'services',
        where: 'is_active = 1 AND _is_deleted = 0',
      );
      availableServices.value = services
          .map((s) => ServiceModel.fromJson(s))
          .toList();
      availableMedicines.value = await _medicineRepo.getAll();
      availableProducts.value = await _productRepo.getAll();
      // Sync staff from cloud first, then load from local
      try {
        await StaffSyncHelper.forceSync();
      } catch (_) {}
      availableStaff.value = await _staffRepo.getActiveStaff();
      // Load cages with occupancy info
      final cages = await _cageRepo.getCagesWithOccupancy();
      availableCages.value = cages
          .where((c) => c.status != 'maintenance')
          .toList();

      // Check if editing existing case
      if (args is MedicalCaseModel) {
        // Deep copy via JSON to ensure nested objects like lists and vital signs don't mutate via reactive state
        _initialCase = MedicalCaseModel.fromJson(args.toJson());
        _isCompleted.value = _initialCase?.status == 'completed';
        isEditing.value = true;
        caseId = args.id;
        caseCode.value = args.caseCode;
        admissionDate.value = args.admissionDate;

        // Load customer and pet
        final customerResult = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [args.customerId],
        );
        if (customerResult.isNotEmpty) {
          selectedCustomer.value = CustomerModel.fromJson(customerResult.first);
          customerNameController.text = selectedCustomer.value!.name;
          phoneController.text = selectedCustomer.value!.phone;
          addressController.text = selectedCustomer.value!.address ?? '';
          await _loadCustomerPets(args.customerId);
        } else {
          // Customer deleted, fallback to snapshot
          customerNameController.text = args.customerName ?? 'Khách Đã xóa';
          phoneController.text = args.phone ?? 'N/A';
          addressController.text = args.address ?? '';
        }

        final petResult = await db.query(
          'pets',
          where: 'id = ?',
          whereArgs: [args.petId],
        );
        if (petResult.isNotEmpty) {
          selectPet(PetModel.fromJson(petResult.first));
        } else {
          // Pet deleted, fallback to snapshot
          petNameController.text = args.petName ?? 'Thú Cưng Đã xóa';
          petSpecies.value = args.species ?? 'N/A';
          speciesRadioValue.value = AppKeys.other;
          otherSpeciesController.text = args.species ?? 'N/A';
        }

        // Load other data
        visitReasons.value = args.visitReasons;
        reasonNotes.value = args.reasonNotes ?? '';
        if (args.vitalSigns != null) {
          temperature.value = args.vitalSigns!.temperature?.toString() ?? '';
          weight.value = args.vitalSigns!.weight?.toString() ?? '';
          vomitingCount.value =
              args.vitalSigns!.vomitingCount?.toString() ?? '';
          stoolCondition.value =
              args.vitalSigns!.stoolCondition ?? AppKeys.stoolNormal;
          mentalStatus.value =
              args.vitalSigns!.mentalStatus ?? AppKeys.mentalAlert;
          bodyCondition.value =
              args.vitalSigns!.bodyCondition ?? AppKeys.bodyNormal;
          skinMucosa.value = args.vitalSigns!.skinMucosa ?? '';
          otherInfo.value = args.vitalSigns!.otherInfo ?? '';
        }
        diagnosis.value = args.diagnosis ?? '';
        prognosis.value = args.prognosis;

        // Advance Payment Logic
        advancePaymentHistory.value = args.advancePaymentHistory;
        advancePayment.value = args.advancePayment; // total accumulated
        newAdvancePaymentInput.value =
            0.0; // Reset active input for new changes
        // Use the latest or default method for the new input
        advancePaymentMethod.value = AppKeys.cash;

        paymentMethod.value = args.paymentMethod;
        customerSignature.value = args.customerSignature;
        clinicSignature.value = args.clinicSignature;
        agreeTreatment.value = args.agreeTreatment;
        agreeNoComplaint.value = args.agreeNoComplaint;
        notes.value = args.notes ?? '';
        notes.value = args.notes ?? '';

        // When editing an existing case, we should assign the form to the *current*
        // logged-in staff member by default, because they are the ones handling it now,
        // rather than keeping the original creator of the case.
        if (Get.isRegistered<PermissionService>() &&
            PermissionService.to.currentStaffName.value != null &&
            PermissionService.to.currentStaffName.value!.isNotEmpty) {
          staffId.value = PermissionService.to.currentStaffName.value!;
          print(
            '[STAFF-DEBUG] _initializeForm() EDIT mode - Auto-assigned current active staffId: "${staffId.value}" over original: "${args.staffId}"',
          );
        } else {
          staffId.value = args.staffId ?? '';
          print(
            '[STAFF-DEBUG] _initializeForm() EDIT mode - loaded original staffId from args: "${args.staffId}" -> staffId.value="${staffId.value}"',
          );
        }

        // Load Hospitalization
        final activeHosp = await db.query(
          'hospitalizations',
          where: 'case_id = ? AND status = ?',
          whereArgs: [args.id, 'active'],
        );
        if (activeHosp.isNotEmpty) {
          isHospitalized.value = true;
          final h = activeHosp.first;
          cageNumber.value = h['cage_number'] as String? ?? '';
          selectedCageId.value = h['cage_id'] as String? ?? '';
        }

        // Load Pending/Confirmed Appointment
        final pendingAppt = await db.query(
          'appointments',
          where: 'pet_id = ? AND status IN (?, ?)',
          whereArgs: [args.petId, 'pending', 'confirmed'],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        if (pendingAppt.isNotEmpty) {
          final apt = pendingAppt.first;
          if (apt['appointment_date'] != null) {
            followUpDate.value = DateTime.parse(
              apt['appointment_date'] as String,
            ).toLocal();
            followUpNote.value = apt['reason'] as String? ?? '';
          }
        }

        // Load services
        final caseServicesData = await DatabaseProvider.instance
            .getCaseServices(args.id);
        selectedServices.value = caseServicesData
            .map((s) => CaseServiceModel.fromJson(s))
            .toList();
        _initialServices = selectedServices
            .map((s) => CaseServiceModel.fromJson(s.toJson()))
            .toList();
        _calculateTotal();
      } else {
        // New case: Get next case code and ensure caseId exists for drafts
        caseId ??= const Uuid().v4();
        caseCode.value = await DatabaseProvider.instance.getNextCaseCode();
        // Auto-assign current staff (dropdown uses staff name as value)
        if (Get.isRegistered<PermissionService>()) {
          staffId.value = PermissionService.to.currentStaffName.value ?? '';
          print(
            '[STAFF-DEBUG] _initializeForm() NEW mode - auto-assigned staffId: "${staffId.value}"',
          );
        }
      }

      // Validate staffId matches an available staff name
      // Dropdown uses staff.name as value, so staffId must match exactly
      if (staffId.value.isNotEmpty) {
        final staffExists = availableStaff.any((s) => s.name == staffId.value);
        if (!staffExists) {
          // staffId might be stored differently, try to find by partial match
          final matchedStaff = availableStaff.firstWhereOrNull(
            (s) =>
                s.name.toLowerCase() == staffId.value.toLowerCase() ||
                s.id == staffId.value,
          );
          if (matchedStaff != null) {
            staffId.value = matchedStaff.name; // Use exact name
          } else {
            // If completely missing, preserve it but it might look like an ID if it was wrongly saved
          }
          // DO NOT reset staffId to '' — keep stored value.
          // The dropdown will include this value even if not in active staff list.
        }
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể khởi tạo form: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Removed old searchCustomerByPhone

  Future<void> _loadCustomerPets(String customerId) async {
    final db = await DatabaseProvider.instance.database;
    final pets = await db.query(
      'pets',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    customerPets.value = pets.map((p) => PetModel.fromJson(p)).toList();

    // Auto select if only one pet
    if (customerPets.length == 1 && !isEditing.value) {
      selectPet(customerPets.first);
    }
  }

  /// Search customer by phone
  void searchCustomerByPhone(String phone) async {
    if (phone.isEmpty) return;

    final db = await DatabaseProvider.instance.database;
    final result = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
    );

    if (result.isNotEmpty) {
      final customer = CustomerModel.fromJson(result.first);
      selectedCustomer.value = customer;
      customerNameController.text = customer.name;
      addressController.text = customer.address ?? '';

      // Load pets
      await _loadCustomerPets(customer.id);

      Get.snackbar(
        'Đã tìm thấy',
        'Khách hàng: ${customer.name}',
        backgroundColor: Colors.green.shade100,
      );
    } else {
      selectedCustomer.value = null;
      // customerNameController.clear(); // Keep input to create new
      // addressController.clear();
      customerPets.clear();
      selectedPet.value = null;
      Get.snackbar(
        'Thông báo',
        'Khách hàng mới, vui lòng nhập thông tin',
        backgroundColor: Colors.blue.shade100,
      );
    }
  }

  // Removed duplicate selectPet

  /// Toggle visit reason
  void toggleVisitReason(String reason) {
    if (visitReasons.contains(reason)) {
      visitReasons.remove(reason);
    } else {
      visitReasons.add(reason);
    }
  }

  /// Toggle service selection
  void toggleService(ServiceModel service) {
    final existingIndex = selectedServices.indexWhere(
      (s) => s.serviceId == service.id,
    );

    if (existingIndex >= 0) {
      final removedService = selectedServices[existingIndex];
      selectedServices.removeAt(existingIndex);
      _deleteAttachmentsForService(removedService.id);
    } else {
      selectedServices.add(
        CaseServiceModel(
          id: uuid.v4(),
          caseId: caseId!,
          serviceId: service.id,
          serviceName: service.name,
          quantity: 1,
          unitPrice: service.basePrice,
        ),
      );
    }
    _calculateTotal();
  }

  /// Add or remove a Petshop product in the bill
  void toggleProduct(ProductModel product) {
    final index = selectedServices.indexWhere((s) => s.serviceId == product.id);
    if (index >= 0) {
      final removedService = selectedServices[index];
      selectedServices.removeAt(index);
      _deleteAttachmentsForService(removedService.id);
    } else {
      selectedServices.add(
        CaseServiceModel(
          id: uuid.v4(),
          caseId: caseId!,
          serviceId: product.id,
          serviceName: 'Petshop: ${product.name}',
          quantity: 1,
          unitPrice: product.salePrice,
        ),
      );
    }
    _calculateTotal();
  }

  /// Add attached medicine to a service
  void addAttachedMedicine(
    String serviceId,
    MedicineModel medicine, {
    String dosage = '',
    String note = '',
    int quantity = 1,
  }) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      final currentService = selectedServices[index];
      // Check if medicine already exists
      final existingMedIndex = currentService.attachedMedicines.indexWhere(
        (m) => m.medicineId == medicine.id,
      );

      List<AttachedMedicineModel> updatedMedicines;
      if (existingMedIndex >= 0) {
        // Update existing
        updatedMedicines = List<AttachedMedicineModel>.from(
          currentService.attachedMedicines,
        );
        final old = updatedMedicines[existingMedIndex];
        updatedMedicines[existingMedIndex] = old.copyWith(
          quantity: old.quantity + quantity,
          dosage: dosage.isNotEmpty ? dosage : old.dosage,
          note: note.isNotEmpty ? note : old.note,
        );
      } else {
        // Add new
        final newMedicine = AttachedMedicineModel(
          medicineId: medicine.id,
          name: medicine.name,
          dosage: dosage,
          note: note,
          quantity: quantity,
        );
        updatedMedicines = List<AttachedMedicineModel>.from(
          currentService.attachedMedicines,
        )..add(newMedicine);
      }

      selectedServices[index] = currentService.copyWith(
        attachedMedicines: updatedMedicines,
      );
      selectedServices.refresh(); // Notify listeners
    }
  }

  /// Remove attached medicine
  void removeAttachedMedicine(String serviceId, int medicineIndex) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      final currentService = selectedServices[index];
      if (medicineIndex >= 0 &&
          medicineIndex < currentService.attachedMedicines.length) {
        final updatedMedicines = List<AttachedMedicineModel>.from(
          currentService.attachedMedicines,
        )..removeAt(medicineIndex);
        selectedServices[index] = currentService.copyWith(
          attachedMedicines: updatedMedicines,
        );
        selectedServices.refresh();
      }
    }
  }

  /// Update attached medicine
  void updateAttachedMedicine(
    String serviceId,
    int medicineIndex,
    AttachedMedicineModel updatedMedicine,
  ) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      final currentService = selectedServices[index];
      if (medicineIndex >= 0 &&
          medicineIndex < currentService.attachedMedicines.length) {
        final updatedMedicines = List<AttachedMedicineModel>.from(
          currentService.attachedMedicines,
        );
        updatedMedicines[medicineIndex] = updatedMedicine;
        selectedServices[index] = currentService.copyWith(
          attachedMedicines: updatedMedicines,
        );
      }
    }
  }

  /// Update service quantity
  void updateServiceQuantity(String serviceId, int quantity) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      if (quantity <= 0) {
        final removedService = selectedServices[index];
        selectedServices.removeAt(index);
        _deleteAttachmentsForService(removedService.id);
      } else {
        selectedServices[index] = selectedServices[index].copyWith(
          quantity: quantity,
        );
      }
      _calculateTotal();
    }
  }

  Future<void> _deleteAttachmentsForService(String caseServiceId) async {
    try {
      if (Get.isRegistered<CaseAttachmentRepository>()) {
        final repo = Get.find<CaseAttachmentRepository>();
        final attachments = await repo.getByService(caseServiceId);
        for (final attachment in attachments) {
          await AttachmentService.to.deleteAttachment(attachment);
        }
      }
    } catch (e) {
      print('Failed to delete attachments for service $caseServiceId: $e');
    }
  }

  /// Update service price (Manual override)
  void updateServicePrice(String serviceId, double newPrice) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      selectedServices[index] = selectedServices[index].copyWith(
        unitPrice: newPrice,
      );
      _calculateTotal();
    }
  }

  /// Update service discount
  void updateServiceDiscount(String serviceId, double newDiscount) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      selectedServices[index] = selectedServices[index].copyWith(
        discount: newDiscount,
      );
      _calculateTotal();
    }
  }

  /// Update service notes
  void updateServiceNotes(String serviceId, String notes) {
    final index = selectedServices.indexWhere((s) => s.serviceId == serviceId);
    if (index >= 0) {
      selectedServices[index] = selectedServices[index].copyWith(notes: notes);
    }
  }

  /// Handle returning a product item from a closed case
  Future<void> returnServiceItem(
    CaseServiceModel item,
    int qty,
    double refundAmount,
  ) async {
    try {
      isLoading.value = true;
      final productId = item.serviceId;
      final productName = item.serviceName.replaceFirst('Petshop: ', '').trim();

      await ReturnService.to.returnCaseServiceItem(
        caseId: caseId!,
        caseServiceId: item.id,
        productId: productId,
        productName: productName,
        returnQty: qty,
        refundAmount: refundAmount,
        caseCode: caseCode.value,
      );

      // Local update to avoid full reload
      final index = selectedServices.indexWhere((s) => s.id == item.id);
      if (index >= 0) {
        final currentNotes = item.notes ?? '';
        final mark = '[Đã trả $qty]';
        selectedServices[index] = item.copyWith(
          notes: currentNotes.isEmpty ? mark : '$currentNotes\n$mark',
        );
        selectedServices.refresh();
      }

      Get.snackbar(
        'Thành công',
        'Đã hoàn trả $qty $productName và tạo phiếu chi hoàn tiền.',
        backgroundColor: AppColors.successLight,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể hoàn trả: $e',
        backgroundColor: AppColors.errorLight,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateTotal() {
    totalEstimate.value = selectedServices.fold(0.0, (sum, s) => sum + s.total);
  }

  double get remainingBalance => totalEstimate.value - advancePayment.value;

  /// Set advance payment
  void setAdvancePayment(String value) {
    if (value.isEmpty) {
      newAdvancePaymentInput.value = 0.0;
      return;
    }
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    newAdvancePaymentInput.value = double.tryParse(cleaned) ?? 0;
  }

  /// Navigate to specific step
  void goToStep(int step) {
    if (step == currentStep.value) return;

    // Allow users to freely switch tabs to view information.
    // Validation is enforced during nextStep() and saveCase().

    // Going back: Pop until we reach the desired step or handle manually
    // Since users can skip steps (e.g., jump from 0 to 3), Get.back() 'diff' times
    // might pop them out of the form entirely.
    // Safe approach: Pop until the root form step (0), then push forward if needed.

    // First, navigate back to the root step (0)
    Get.until(
      (route) {
        final name = route.settings.name ?? '';
        return name == Routes.caseCreate || 
               name == Routes.cases ||
               name == Routes.home ||
               route.isFirst;
      }
    );

    // Then navigate forward to the desired step
    currentStep.value = step;
    if (step > 0) {
      _navigateToStep(step);
    }
  }

  /// Navigate to next step
  void nextStep() {
    if (currentStep.value < 3) {
      if (_validateCurrentStep()) {
        currentStep.value++;
        _navigateToStep(currentStep.value);
      }
    }
  }

  /// Navigate to previous step
  void previousStep() {
    if (currentStep.value > 0) {
      goToStep(currentStep.value - 1);
    }
  }

  void _navigateToStep(int step) {
    switch (step) {
      case 0:
        // Usually initial route
        break;
      case 1:
        Get.toNamed(Routes.caseClinicalExam);
        break;
      case 2:
        Get.toNamed(Routes.caseDiagnosis);
        break;
      case 3:
        Get.toNamed(Routes.casePayment);
        break;
    }
  }

  bool _validateCurrentStep() {
    switch (currentStep.value) {
      case 0: // Basic info
        if (phoneController.text.isEmpty) {
          Get.snackbar('Lỗi', 'Vui lòng nhập số điện thoại');
          return false;
        }
        if (customerNameController.text.isEmpty) {
          Get.snackbar('Lỗi', 'Vui lòng nhập tên khách hàng');
          return false;
        }
        if (petNameController.text.isEmpty) {
          Get.snackbar('Lỗi', 'Vui lòng nhập tên thú cưng');
          return false;
        }
        return true;
      case 1: // Clinical exam
        return true; // All fields optional
      case 2: // Diagnosis
        return true; // All fields optional
      default:
        return true;
    }
  }

  final MedicalCaseRepository _medicalCaseRepository = MedicalCaseRepository();

  /// Save the complete case
  Future<void> saveCase() async {
    if (!agreeTreatment.value) {
      Get.snackbar('Lỗi', 'Vui lòng xác nhận đồng ý phác đồ điều trị');
      return;
    }

    isSaving.value = true;
    try {
      final now = DateTime.now();

      // Get clinic_id
      final clinicId = Get.isRegistered<AuthService>()
          ? AuthService.to.currentProfile.value?.clinicId
          : null;

      // 1. Prepare Customer
      String customerId;
      CustomerModel customer;

      if (selectedCustomer.value != null) {
        customerId = selectedCustomer.value!.id;
        customer = selectedCustomer.value!.copyWith(
          name: customerNameController.text,
          address: addressController.text,
          updatedAt: now,
          phone: phoneController.text.replaceAll(
            RegExp(r'\D'),
            '',
          ), // Ensure phone is consistent
        );
      } else {
        customerId = uuid.v4();
        customer = CustomerModel(
          id: customerId,
          clinicId: clinicId,
          phone: phoneController.text.replaceAll(RegExp(r'\D'), ''),
          name: customerNameController.text,
          address: addressController.text,
        );
        selectedCustomer.value = customer;
      }

      // 2. Prepare Pet
      String petId;
      PetModel pet;

      final finalSpecies =
          petSpecies.value == 'other' && otherSpeciesController.text.isNotEmpty
          ? otherSpeciesController.text
          : petSpecies.value;

      if (selectedPet.value != null) {
        petId = selectedPet.value!.id;
        int? ageValue = int.tryParse(petAgeController.text);
        String? computedDob;
        if (ageValue != null) {
          final now = DateTime.now();
          if (petAgeUnit.value == 'Năm') {
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
            // handle days logic simply, maybe 1st of month:
            computedDob = DateTime(birthYear, birthMonth, 1).toIso8601String();
          }
        }

        pet = selectedPet.value!.copyWith(
          name: petNameController.text,
          species: finalSpecies,
          breed: petBreedController.text,
          dateOfBirth: computedDob,
          age: ageValue, // fallback backward compatibility
          gender: petGender.value,
          updatedAt: now,
        );
      } else {
        petId = uuid.v4();
        int? ageValue = int.tryParse(petAgeController.text);
        String? computedDob;
        if (ageValue != null) {
          final now = DateTime.now();
          if (petAgeUnit.value == 'Năm') {
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

        pet = PetModel(
          id: petId,
          clinicId: clinicId,
          customerId: customerId,
          name: petNameController.text,
          species: finalSpecies,
          breed: petBreedController.text.isNotEmpty
              ? petBreedController.text
              : null,
          dateOfBirth: computedDob,
          age: ageValue,
          gender: petGender.value,
        );
        selectedPet.value = pet;
      }

      // 3. Prepare Vital Signs
      final vitalSigns = VitalSignsModel(
        temperature: double.tryParse(temperature.value),
        weight: double.tryParse(weight.value),
        vomitingCount: int.tryParse(vomitingCount.value),
        stoolCondition: stoolCondition.value,
        mentalStatus: mentalStatus.value,
        bodyCondition: bodyCondition.value,
        skinMucosa: skinMucosa.value.isNotEmpty ? skinMucosa.value : null,
        otherInfo: otherInfo.value.isNotEmpty ? otherInfo.value : null,
      );

      // Resolve True UUID from Staff Name for Sync Compatibility
      String? actualStaffId;
      if (staffId.value.isNotEmpty) {
        final matched = availableStaff.firstWhereOrNull(
          (s) => s.name == staffId.value,
        );
        actualStaffId = matched?.id;
        if (actualStaffId == null) {
          // Fallback just in case it ALREADY holds a UUID for some reason
          actualStaffId = staffId.value;
        }
      }

      // 3.5 Processing Advance Payment History Increment
      final List<AdvancePaymentRecord> updatedAdvanceHistory = List.from(
        advancePaymentHistory,
      );
      double updatedTotalAdvance = advancePayment.value;
      if (newAdvancePaymentInput.value > 0) {
        updatedAdvanceHistory.add(
          AdvancePaymentRecord(
            amount: newAdvancePaymentInput.value,
            method: advancePaymentMethod.value,
            date: now,
          ),
        );
        updatedTotalAdvance += newAdvancePaymentInput.value;
      }

      // 4. Prepare Medical Case
      final currentCaseId = caseId!;
      final medicalCase = MedicalCaseModel(
        id: currentCaseId,
        clinicId: clinicId,
        caseCode: caseCode.value,
        customerId: customerId,
        customerName: customer.name.isNotEmpty
            ? customer.name
            : customerNameController.text,
        phone: customer.phone.isNotEmpty
            ? customer.phone
            : phoneController.text,
        petId: petId,
        petName: pet.name.isNotEmpty ? pet.name : petNameController.text,
        species: pet.species.isNotEmpty ? pet.species : finalSpecies,
        admissionDate: admissionDate.value,
        visitReasons: visitReasons.toList(),
        reasonNotes: reasonNotes.value.isNotEmpty ? reasonNotes.value : null,
        vitalSigns: vitalSigns,
        diagnosis: diagnosis.value.isNotEmpty ? diagnosis.value : null,
        prognosis: prognosis.value,
        treatmentPlan: treatmentPlan.value.isNotEmpty
            ? treatmentPlan.value
            : null,
        totalEstimate: totalEstimate.value,
        advancePayment: updatedTotalAdvance,
        advancePaymentMethod: advancePaymentMethod
            .value, // Keep last used method for legacy/simple logic
        advancePaymentHistory: updatedAdvanceHistory,
        paymentMethod: paymentMethod.value,
        customerSignature: customerSignature.value,
        clinicSignature: clinicSignature.value,
        agreeTreatment: agreeTreatment.value,
        agreeNoComplaint: agreeNoComplaint.value,
        notes: notes.value.isNotEmpty ? notes.value : null,
        staffId: actualStaffId,
        status: isEditing.value ? (_initialCase?.status ?? 'active') : 'active',
        createdAt: isEditing.value ? null : now,
        updatedAt: now,
      );

      print(
        '[STAFF-DEBUG] saveCase() - staffId.value="${staffId.value}", model.staffId="${medicalCase.staffId}", isEditing=${isEditing.value}, caseId=$currentCaseId',
      );
      print(
        '[STAFF-DEBUG] saveCase() - toJson staff_id=${medicalCase.toJson()['staff_id']}',
      );

      // 5. Prepare Appointment Data (Optional)
      Map<String, dynamic>? appointmentData;
      if (followUpDate.value != null) {
        final timeString =
            "${followUpDate.value!.hour.toString().padLeft(2, '0')}:${followUpDate.value!.minute.toString().padLeft(2, '0')}";
        appointmentData = {
          'id': uuid.v4(),
          'clinic_id': clinicId,
          'customer_id': customerId,
          'pet_id': petId,
          'appointment_date': followUpDate.value!.toUtc().toIso8601String(),
          'time': timeString,
          'status': 'confirmed',
          'reason': followUpNote.value.isNotEmpty
              ? followUpNote.value
              : 'Tái khám ca #${caseCode.value}',
          'created_at': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
          'sync_status': 'pending',
        };
      }

      // 6. Prepare Hospitalization Data (Optional)
      Map<String, dynamic>? hospitalizationData;
      if (isHospitalized.value) {
        hospitalizationData = {
          'id': uuid.v4(),
          'case_id': currentCaseId,
          'pet_id': petId,
          'admission_date': now.toUtc().toIso8601String(),
          'cage_number': cageNumber.value,
          'cage_id': selectedCageId.value,
          'status': 'active',
          'created_at': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
        };
      }

      // 7. Prepare Audit Log
      final currentUserId = AuthService.to.currentProfile.value?.id;
      final currentUserName =
          AuthService.to.currentProfile.value?.fullName ?? 'Hệ thống';
      final isNewCase = !isEditing.value;

      String updateNotes = isNewCase
          ? 'Tạo mới bệnh án'
          : 'Cập nhật nội dung bệnh án';
      String? updateMetadata;
      if (isEditing.value && _initialCase != null) {
        List<String> changes = [];
        Map<String, dynamic> diffMap = {};

        final currencyFormatter = NumberFormat.currency(
          locale: 'vi_VN',
          symbol: 'đ',
        );

        String formatValue(String key, dynamic val) {
          if (val == null) return 'Trống';
          // Currency formatting
          if (key == 'Tổng dịch vụ/Thuốc' || key == 'Tiền ứng') {
            return currencyFormatter.format(val);
          }
          // Mapping dictionary
          final Map<String, String> translationMap = {
            'mental_alert': 'Tỉnh táo',
            'mental_tired': 'Mệt mỏi',
            'mental_lethargic': 'Lờ đờ',
            'mental_drowsy': 'Hôn mê nhẹ',
            'mental_coma': 'Hôn mê',
            'mental_restless': 'Kích động',
            'body_normal': 'Bình thường',
            'body_thin': 'Gầy',
            'body_fat': 'Béo',
            'body_obese': 'Béo phì',
            'stool_normal': 'Bình thường',
            'stool_liquid': 'Phân lỏng',
            'stool_hard': 'Phân cứng',
            'stool_blood': 'Phân lẫn máu',
            'active': 'Đang điều trị',
            'completed': 'Hoàn thành',
            'cancelled': 'Đã hủy',
            'vomit': 'Nôn mửa',
            'weak': 'Yếu',
            'tired': 'Mệt mỏi',
            'accident': 'Tai nạn',
            'fever': 'Sốt',
            'diarrhea': 'Tiêu chảy',
            'nopet': 'Bỏ ăn',
            'breath': 'Khó thở',
            'itch': 'Ngứa / Viêm da',
          };

          if (val is String) {
            // For visit reasons which is comma separated
            if (key == 'Triệu chứng') {
              return val
                  .split(',')
                  .map((e) => translationMap[e.trim()] ?? e.trim())
                  .join(', ');
            }
            return translationMap[val] ?? val;
          }
          return val.toString();
        }

        void trackDiff(String fieldName, dynamic oldVal, dynamic newVal) {
          changes.add(fieldName);
          diffMap[fieldName] = {
            'old': formatValue(fieldName, oldVal),
            'new': formatValue(fieldName, newVal),
          };
        }

        if (_initialCase!.diagnosis != medicalCase.diagnosis)
          trackDiff(
            'Chẩn đoán',
            _initialCase!.diagnosis,
            medicalCase.diagnosis,
          );
        if (_initialCase!.treatmentPlan != medicalCase.treatmentPlan)
          trackDiff(
            'Phác đồ',
            _initialCase!.treatmentPlan,
            medicalCase.treatmentPlan,
          );
        if (_initialCase!.notes != medicalCase.notes)
          trackDiff('Ghi chú nội bộ', _initialCase!.notes, medicalCase.notes);
        if (_initialCase!.reasonNotes != medicalCase.reasonNotes)
          trackDiff(
            'Ghi chú Khám LS',
            _initialCase!.reasonNotes,
            medicalCase.reasonNotes,
          );
        if (_initialCase!.status != medicalCase.status)
          trackDiff('Trạng thái', _initialCase!.status, medicalCase.status);
        if (_initialCase!.vitalSigns?.weight != medicalCase.vitalSigns?.weight)
          trackDiff(
            'Cân nặng',
            _initialCase!.vitalSigns?.weight,
            medicalCase.vitalSigns?.weight,
          );
        if (_initialCase!.vitalSigns?.temperature !=
            medicalCase.vitalSigns?.temperature)
          trackDiff(
            'Nhiệt độ',
            _initialCase!.vitalSigns?.temperature,
            medicalCase.vitalSigns?.temperature,
          );
        if (_initialCase!.vitalSigns?.mentalStatus !=
            medicalCase.vitalSigns?.mentalStatus)
          trackDiff(
            'Tinh thần',
            _initialCase!.vitalSigns?.mentalStatus,
            medicalCase.vitalSigns?.mentalStatus,
          );
        if (_initialCase!.vitalSigns?.skinMucosa !=
            medicalCase.vitalSigns?.skinMucosa)
          trackDiff(
            'Niêm mạc',
            _initialCase!.vitalSigns?.skinMucosa,
            medicalCase.vitalSigns?.skinMucosa,
          );
        // Bỏ tracking 'Tổng dịch vụ/Thuốc' theo yêu cầu của user vì gây rối mắt

        // Cập nhật cách tính Log cho tiền ứng
        if (newAdvancePaymentInput.value > 0) {
          changes.add('Ứng tiền');
          final dot = medicalCase.advancePaymentHistory.length;
          diffMap['Ứng tiền'] = {
            'old': 'Chưa ứng đợt $dot',
            'new':
                'Đã ứng đợt $dot: ${currencyFormatter.format(newAdvancePaymentInput.value)}',
          };
        }

        final oldReasons = _initialCase!.visitReasons.join(',');
        final newReasons = medicalCase.visitReasons.join(',');
        if (oldReasons != newReasons)
          trackDiff('Triệu chứng', oldReasons, newReasons);

        // Track deep service and medicine changes
        List<String> addedItems = [];
        List<String> removedItems = [];

        // Check Services
        for (var current in selectedServices) {
          if (!_initialServices.any((s) => s.serviceId == current.serviceId)) {
            addedItems.add('DV: ${current.serviceName}');
          }

          // Check attached medicines for existing services
          final initialService = _initialServices.firstWhereOrNull(
            (s) => s.serviceId == current.serviceId,
          );
          if (initialService != null) {
            for (var med in current.attachedMedicines) {
              if (!initialService.attachedMedicines.any(
                (m) => m.medicineId == med.medicineId,
              )) {
                addedItems.add('Thuốc: ${med.name}');
              }
            }
            for (var med in initialService.attachedMedicines) {
              if (!current.attachedMedicines.any(
                (m) => m.medicineId == med.medicineId,
              )) {
                removedItems.add('Thuốc: ${med.name}');
              }
            }
          }
        }
        for (var initial in _initialServices) {
          if (!selectedServices.any((s) => s.serviceId == initial.serviceId)) {
            removedItems.add('DV: ${initial.serviceName}');
          }
        }

        if (addedItems.isNotEmpty || removedItems.isNotEmpty) {
          changes.add('Chi tiết Dịch vụ');
          String oldNotes = "Không đổi";
          String newNotes = "";
          if (removedItems.isNotEmpty)
            oldNotes = "Đã xóa:\n- ${removedItems.join('\n- ')}";
          if (addedItems.isNotEmpty)
            newNotes = "Đã thêm:\n- ${addedItems.join('\n- ')}";

          if (removedItems.isNotEmpty && addedItems.isEmpty)
            newNotes = "Không thêm mới";
          if (addedItems.isNotEmpty && removedItems.isEmpty)
            oldNotes = "Không xóa";

          diffMap['Chi tiết Dịch vụ'] = {'old': oldNotes, 'new': newNotes};
        }

        if (changes.isNotEmpty) {
          updateNotes = 'Cập nhật: ${changes.join(', ')}';
          // Convert map to JSON safely so it can be parsed later in the UI table
          updateMetadata = jsonEncode(diffMap);
        }
      }

      final caseLog = CaseLogModel(
        clinicId: clinicId ?? '',
        caseId: currentCaseId,
        staffId: Get.isRegistered<PermissionService>()
            ? PermissionService.to.currentStaffId.value
            : currentUserId, // Log the person actively using the POS (PIN)
        action: isNewCase ? 'CREATED' : 'UPDATED',
        notes: updateNotes,
        metadata: updateMetadata,
        staffName:
            Get.isRegistered<PermissionService>() &&
                PermissionService.to.currentStaffName.value != null &&
                PermissionService.to.currentStaffName.value!.isNotEmpty
            ? PermissionService.to.currentStaffName.value
            : currentUserName,
      );

      // EXECUTE TRANSACTION via Repository
      await _medicalCaseRepository.saveCompleteCase(
        customer: customer,
        pet: pet,
        medicalCase: medicalCase,
        services: selectedServices,
        vitalSigns: vitalSigns,
        clinicId: clinicId,
        appointmentData: appointmentData,
        hospitalizationData: hospitalizationData,
        logs: [caseLog],
        cageIdToOccupy: selectedCageId.value.isNotEmpty
            ? selectedCageId.value
            : null,
        isUpdate: isEditing.value,
      );

      Get.snackbar(
        'Thành công',
        isEditing.value
            ? 'Đã cập nhật ca bệnh'
            : 'Đã lưu ca bệnh #${caseCode.value}',
      );

      // Update state to Editing mode if it was new
      if (!isEditing.value) {
        caseId = currentCaseId;
        isEditing.value = true;
        // Prevent reinitialize() from wiping state on widget rebuild
        _lastInitSession = currentCaseId;
      }

      // Reset local new advance payment memory so pressing Save twice doesn't charge again
      if (newAdvancePaymentInput.value > 0) {
        advancePayment.value =
            updatedTotalAdvance; // reflect current accumulated internally
        advancePaymentHistory.value =
            updatedAdvanceHistory; // reflect UI array updates
        newAdvancePaymentInput.value = 0.0;
        advancePaymentController.clear();
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể lưu ca bệnh: $e');
      print('Error saving case: $e'); // Log for debugging
    } finally {
      isSaving.value = false;
    }
  }

  /// Update Hospitalization Service based on Cage selection
  void updateHospitalizationService(String? cageId) {
    if (cageId == null || cageId.isEmpty) {
      selectedServices.removeWhere(
        (s) => s.serviceName.toLowerCase().contains('lưu chuồng'),
      );
      _calculateTotal();
      return;
    }

    final cage = availableCages.firstWhereOrNull((c) => c.id == cageId);
    if (cage == null) return;

    // Check if already exists
    final existingIndex = selectedServices.indexWhere(
      (s) => s.serviceName.toLowerCase().contains('lưu chuồng'),
    );

    if (existingIndex >= 0) {
      final s = selectedServices[existingIndex];
      selectedServices[existingIndex] = s.copyWith(unitPrice: cage.price);
    } else {
      // Add new
      final serviceTemplate = availableServices.firstWhereOrNull(
        (s) =>
            s.name.toLowerCase().contains('lưu chuồng') ||
            s.name.toLowerCase().contains('lưu viện') ||
            s.category == 'hospitalization',
      );

      if (serviceTemplate != null) {
        selectedServices.add(
          CaseServiceModel(
            id: uuid.v4(),
            caseId: '',
            serviceId: serviceTemplate.id,
            serviceName: serviceTemplate.name,
            quantity: 1,
            unitPrice: cage.price,
          ),
        );
      } else {
        // Create ad-hoc service if template missing
        selectedServices.add(
          CaseServiceModel(
            id: uuid.v4(),
            caseId: '',
            serviceId: 'adhoc_hospitalization', // Virtual ID
            serviceName: 'Lưu chuồng (${cage.name})',
            quantity: 1,
            unitPrice: cage.price,
          ),
        );
      }
    }
    _calculateTotal();
  }

  /// Preview and Print medical record
  Future<void> previewPdf() async {
    if (selectedCustomer.value == null || selectedPet.value == null) {
      Get.snackbar('Lỗi', 'Chưa có thông tin khách hàng hoặc thú cưng');
      return;
    }

    final medicalCase = MedicalCaseModel(
      id: isEditing.value ? caseId! : uuid.v4(), // Use existing ID or temp
      caseCode: caseCode.value,
      customerId: selectedCustomer.value!.id,
      petId: selectedPet.value!.id,
      admissionDate: admissionDate.value,
      visitReasons: visitReasons.toList(),
      reasonNotes: reasonNotes.value,
      vitalSigns: VitalSignsModel(
        temperature: double.tryParse(temperature.value),
        weight: double.tryParse(weight.value),
        vomitingCount: int.tryParse(vomitingCount.value),
        stoolCondition: stoolCondition.value,
        mentalStatus: mentalStatus.value,
        bodyCondition: bodyCondition.value,
        skinMucosa: skinMucosa.value,
        otherInfo: otherInfo.value,
      ),
      diagnosis: diagnosis.value,
      prognosis: prognosis.value,
      treatmentPlan: treatmentPlan.value, // Added missing field
      totalEstimate: totalEstimate.value,
      advancePayment: advancePayment.value,
      paymentMethod: paymentMethod.value,
      customerSignature: customerSignature.value,
      clinicSignature: clinicSignature.value,
      agreeTreatment: agreeTreatment.value,
      agreeNoComplaint: agreeNoComplaint.value,
      notes: notes
          .value, // Notes was already here, but PdfService wasn't using it.

      staffId: staffId.value,
      status: 'active',
    );

    Get.to(
      () => PdfPreviewView(
        title: 'Bệnh Án - #${caseCode.value}',
        initialPageFormat: PdfPageFormat.a4,
        buildPdf: () => _pdfService.generateMedicalCasePdf(
          medicalCase: medicalCase,
          customer: selectedCustomer.value!,
          pet: selectedPet.value!,
          services: selectedServices,
        ),
      ),
    );
  }

  /// Preview and Print Invoice (Hóa đơn)
  Future<void> previewInvoice() async {
    if (selectedCustomer.value == null || selectedPet.value == null) {
      Get.snackbar('Lỗi', 'Chưa có thông tin khách hàng hoặc thú cưng');
      return;
    }

    final medicalCase = MedicalCaseModel(
      id: isEditing.value ? caseId! : uuid.v4(),
      caseCode: caseCode.value,
      customerId: selectedCustomer.value!.id,
      petId: selectedPet.value!.id,
      admissionDate: admissionDate.value,
      visitReasons: visitReasons.toList(),
      reasonNotes: reasonNotes.value,
      vitalSigns: VitalSignsModel(
        temperature: double.tryParse(temperature.value),
        weight: double.tryParse(weight.value),
        vomitingCount: int.tryParse(vomitingCount.value),
        stoolCondition: stoolCondition.value,
        mentalStatus: mentalStatus.value,
        bodyCondition: bodyCondition.value,
        skinMucosa: skinMucosa.value,
        otherInfo: otherInfo.value,
      ),
      diagnosis: diagnosis.value,
      prognosis: prognosis.value,
      totalEstimate: totalEstimate.value,
      advancePayment: advancePayment.value,
      paymentMethod: paymentMethod.value,
      customerSignature: customerSignature.value,
      clinicSignature: clinicSignature.value,
      agreeTreatment: agreeTreatment.value,
      agreeNoComplaint: agreeNoComplaint.value,
      notes: notes.value,
      staffId: staffId.value,
      status: 'active',
    );

    Get.to(
      () => PdfPreviewView(
        title: 'Hóa Đơn - #${caseCode.value}',
        initialPageFormat: PdfPageFormat.a5,
        buildPdf: () => _pdfService.generateInvoicePdf(
          medicalCase: medicalCase,
          customer: selectedCustomer.value!,
          pet: selectedPet.value!,
          services: selectedServices,
        ),
      ),
    );
  }

  /// Cancel and go back
  void cancelForm() {
    Get.dialog(
      AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
          'Bạn có chắc muốn hủy? Dữ liệu chưa lưu sẽ bị mất.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Không')),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog

              // Navigate back to case list instead of home
              // Pop all case form routes until we reach the case list or home
              try {
                Get.until((route) {
                  final name = route.settings.name ?? '';
                  return name == Routes.cases || name == Routes.home || route.isFirst;
                });
              } catch (_) {
                Get.offAllNamed(Routes.cases);
              }

              // Cleanup controller
              Get.delete<CaseFormController>(force: true);
            },
            child: const Text('Có, hủy'),
          ),
        ],
      ),
    );
  }

  /// Discharge/Finalize Case (Xuất viện)
  Future<void> dischargeCase({String settlementMethod = 'cash'}) async {
    if (!agreeTreatment.value) {
      Get.snackbar('Lỗi', 'Vui lòng xác nhận đồng ý phác đồ điều trị');
      return;
    }

    // Save first to ensure everything is up to date

    isSaving.value = true;
    try {
      final db = await DatabaseProvider.instance.database;
      final now = DateTime.now();

      // Update Medical Case Status
      final currentCaseId = isEditing.value ? caseId! : throw 'Case ID needed';

      await db.update(
        'medical_cases',
        {
          'status': 'completed', // Completed/Discharged
          'payment_method': settlementMethod, // Update final payment method
          'advance_payment': advancePayment.value,
          'advance_payment_method': advancePaymentMethod.value,
          'discharge_date': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
          '_sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [currentCaseId],
      );
      // Track for sync
      if (Get.isRegistered<SyncEngine>()) {
        await SyncEngine.to.trackChange(
          table: 'medical_cases',
          recordId: currentCaseId,
          operation: ChangeOperation.update,
        );
      }

      // Inventory Deduction
      for (final service in selectedServices) {
        for (final medicine in service.attachedMedicines) {
          await _medicineRepo.createTransaction(
            MedicineTransactionModel(
              id: uuid.v4(),
              medicineId: medicine.medicineId,
              type: 'use',
              quantity: medicine.quantity.toDouble(),
              caseId: currentCaseId,
              purpose:
                  'Sử dụng cho ca bệnh #${caseCode.value} - ${service.serviceName}',
              staffId: staffId.value,
            ),
          );
        }
      }

      // Update Hospitalization if any
      if (isHospitalized.value) {
        // Get active hospitalization to find usage
        final activeHosp = await db.query(
          'hospitalizations',
          where: 'case_id = ? AND status = ?',
          whereArgs: [currentCaseId, 'active'],
        );

        if (activeHosp.isNotEmpty) {
          final hosp = activeHosp.first;
          final cageId = hosp['cage_id'] as String?;
          // Release cage
          if (cageId != null && cageId.isNotEmpty) {
            await _cageRepo.updateCageStatus(cageId, 'available');
          }
        }

        await db.update(
          'hospitalizations',
          {
            'status': 'discharged',
            'discharge_date': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
            '_sync_status': 'pending',
          },
          where: 'case_id = ? AND status = ?',
          whereArgs: [currentCaseId, 'active'],
        );
        // Track hospitalization discharge for sync
        if (Get.isRegistered<SyncEngine>() && activeHosp.isNotEmpty) {
          final hospId = activeHosp.first['id'] as String?;
          if (hospId != null) {
            await SyncEngine.to.trackChange(
              table: 'hospitalizations',
              recordId: hospId,
              operation: ChangeOperation.update,
            );
          }
        }
      }

      Get.snackbar('Thành công', 'Đã xuất viện và quyết toán ca bệnh!');

      await Get.offAllNamed(Routes.cases);
      await Future.delayed(const Duration(milliseconds: 300));
      if (Get.isRegistered<CaseFormController>()) {
        Get.delete<CaseFormController>(force: true);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất viện: $e');
    } finally {
      isSaving.value = false;
    }
  }
}
