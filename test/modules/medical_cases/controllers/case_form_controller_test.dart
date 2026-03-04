import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:okada_vet_clinic/core/constants/app_keys.dart';
import 'package:okada_vet_clinic/data/models/customer_model.dart';
import 'package:okada_vet_clinic/data/models/medical_case_model.dart';
import 'package:okada_vet_clinic/data/models/pet_model.dart';
import 'package:okada_vet_clinic/data/models/service_model.dart';
import 'package:okada_vet_clinic/data/providers/local/database_provider.dart';
import 'package:okada_vet_clinic/modules/medical_cases/controllers/case_form_controller.dart';
import 'package:okada_vet_clinic/services/pdf_service.dart';

// Manual Fake for GetxService
class FakePdfService extends GetxService implements PdfService {
  @override
  Future<Uint8List> generateMedicalCasePdf({required MedicalCaseModel medicalCase, required CustomerModel customer, required PetModel pet, required List<CaseServiceModel> services}) async => Uint8List(0);

  @override
  Future<Uint8List> generateInvoicePdf({required MedicalCaseModel medicalCase, required CustomerModel customer, required PetModel pet, required List<CaseServiceModel> services}) async => Uint8List(0);
  
  @override
  Future<void> printMedicalCase({required MedicalCaseModel medicalCase, required CustomerModel customer, required PetModel pet, required List<CaseServiceModel> services}) async {}
  
  @override
  Future<void> shareMedicalCase({required MedicalCaseModel medicalCase, required CustomerModel customer, required PetModel pet, required List<CaseServiceModel> services}) async {}

  @override
  Future<void> printInvoice({required MedicalCaseModel medicalCase, required CustomerModel customer, required PetModel pet, required List<CaseServiceModel> services}) async {}
  
  @override
  Future<void> shareInvoice({required MedicalCaseModel medicalCase, required CustomerModel customer, required PetModel pet, required List<CaseServiceModel> services}) async {}
  
  // GetxService overrides to ensure lifecycle compatibility
  @override
  InternalFinalCallback<void> get onStart => super.onStart;
  
  @override
  InternalFinalCallback<void> get onDelete => super.onDelete;
  
  @override
  bool get initialized => true;

  @override
  bool get isClosed => false;
}

void main() {
  late CaseFormController controller;
  late FakePdfService fakePdfService;

  setUpAll(() async {
    // Initialize in-memory database
    await DatabaseProvider.instance.initInMemory();
  });

  setUp(() {
    Get.testMode = true;
    fakePdfService = FakePdfService();
    Get.put<PdfService>(fakePdfService);
    
    controller = CaseFormController();
    // Manually trigger onInit
    controller.onInit();
  });

  tearDown(() async {
    Get.reset();
    await DatabaseProvider.instance.clearAll();
  });

  group('CaseFormController Tests', () {
    test('Initial State should use AppKeys', () {
      expect(controller.currentStep.value, 0);
      expect(controller.petGender.value, AppKeys.male);
      expect(controller.stoolCondition.value, AppKeys.stoolNormal);
      expect(controller.mentalStatus.value, AppKeys.mentalAlert);
      expect(controller.bodyCondition.value, AppKeys.bodyNormal);
      expect(controller.skinMucosa.value, '');
      expect(controller.visitReasonOptions.contains(AppKeys.vomit), true);
    });

    test('Status fields should update correctly', () {
      controller.mentalStatus.value = AppKeys.mentalLethargic;
      expect(controller.mentalStatus.value, AppKeys.mentalLethargic);
      
      controller.skinMucosa.value = 'Hồng hào';
      expect(controller.skinMucosa.value, 'Hồng hào');
    });

    test('selectPet should update fields correctly with AppKeys', () {
      final pet = PetModel(
        id: 'pet_123',
        customerId: 'cust_123',
        name: 'Mimi',
        species: AppKeys.cat,
        gender: AppKeys.female,
        age: 2,
      );

      controller.selectPet(pet);

      expect(controller.selectedPet.value, pet);
      expect(controller.petNameController.text, 'Mimi');
      expect(controller.petSpecies.value, AppKeys.cat);
      expect(controller.speciesRadioValue.value, AppKeys.cat);
      expect(controller.petGender.value, AppKeys.female);
    });

    test('selectPet with "Other" species', () {
      final pet = PetModel(
        id: 'pet_456',
        customerId: 'cust_123',
        name: 'Coco',
        species: 'Hamster', // Not Dog or Cat
        gender: AppKeys.male,
      );

      controller.selectPet(pet);

      expect(controller.petSpecies.value, 'Hamster');
      expect(controller.speciesRadioValue.value, AppKeys.other);
      expect(controller.otherSpeciesController.text, 'Hamster');
    });

    /*
    test('Validation Step 0 - Empty fields', () {
      // Ensure fields are empty
      controller.phoneController.text = '';
      controller.customerNameController.text = '';
      controller.petNameController.text = '';

      // Try go to step 1
      try {
        controller.nextStep();
      } catch (_) {
        // Ignore Get.snackbar error regarding missing Overlay
      }

      // Should stay at step 0
      expect(controller.currentStep.value, 0);
    });
    */

    test('Validation Step 0 - Success', () {
      controller.phoneController.text = '0909000111';
      controller.customerNameController.text = 'Nguyen Van A';
      controller.petNameController.text = 'Lu';

      // Next step
      controller.nextStep();

      // Should move to step 1
      expect(controller.currentStep.value, 1);
    });

    test('Service Management - Toggle and Calculation', () {
      final service1 = ServiceModel(
        id: 'svc1', 
        name: 'Service 1', 
        basePrice: 100.0,
        category: 'test',
        unit: 'time'
      );
      
      final service2 = ServiceModel(
        id: 'svc2', 
        name: 'Service 2', 
        basePrice: 200.0,
        category: 'test',
        unit: 'time'
      );

      // Add Service 1
      controller.toggleService(service1);
      expect(controller.selectedServices.length, 1);
      expect(controller.totalEstimate.value, 100.0);

      // Add Service 2
      controller.toggleService(service2);
      expect(controller.selectedServices.length, 2);
      expect(controller.totalEstimate.value, 300.0);

      // Remove Service 1 (Toggle again)
      controller.toggleService(service1);
      expect(controller.selectedServices.length, 1);
      expect(controller.totalEstimate.value, 200.0);
    });

    test('Update Service Quantity', () {
      final service = ServiceModel(
        id: 'svc1', 
        name: 'Service 1', 
        basePrice: 100.0,
        category: 'test',
        unit: 'time'
      );

      controller.toggleService(service);
      
      // Update quantity to 3
      controller.updateServiceQuantity('svc1', 3);
      
      final selected = controller.selectedServices.first;
      expect(selected.quantity, 3);
      expect(selected.total, 300.0); // 100 * 3
      expect(controller.totalEstimate.value, 300.0);
    });
    
    test('Visit Reasons Toggling', () {
      // Add 'vomit' key
      controller.toggleVisitReason(AppKeys.vomit);
      expect(controller.visitReasons.contains(AppKeys.vomit), true);
      
      // Add 'fever' key
      controller.toggleVisitReason(AppKeys.fever);
      expect(controller.visitReasons.length, 2);
      
      // Remove 'vomit' key
      controller.toggleVisitReason(AppKeys.vomit);
      expect(controller.visitReasons.contains(AppKeys.vomit), false);
      expect(controller.visitReasons.length, 1);
    });
  });
}
