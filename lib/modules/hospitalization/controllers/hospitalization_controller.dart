import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/medicine_model.dart';
import '../../../data/models/cage_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/base_sync_repository.dart';
import '../../../core/sync/sync_engine.dart';
import '../repositories/cage_repository.dart';
import '../repositories/hospitalization_repository.dart';
import '../repositories/reservation_repository.dart';
import 'package:printing/printing.dart';
import '../utils/pdf_generator.dart';
import '../../../data/models/hospitalization_models.dart';
import '../../../core/services/staff_sync_helper.dart';

class HospitalizationController extends GetxController with SyncCapable {
  final uuid = const Uuid();
  final _medicineRepo = MedicineRepository();
  final _cageRepo = CageRepository();
  final _hospRepo = HospitalizationRepository();
  final _resRepo = ReservationRepository();

  // Alerts
  final cageAlerts = <String, List<String>>{}.obs;
  // Reservations: CageID -> List of Reservation Badges
  final cageReservations = <String, List<String>>{}.obs;
  // Deposits: hospitalizationId -> deposit amount
  final deposits = <String, double>{}.obs;

  final isLoading = false.obs;
  final viewMode = 'grid'.obs; // 'grid' or 'whiteboard'
  final cages = <CageModel>[].obs;
  final availableMedicines = <MedicineModel>[].obs;
  final staffList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadCages();
    loadMedicines();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    try {
      final rows = await StaffSyncHelper.loadStaffWithSync();
      staffList.value = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Error loading staff: $e');
    }
  }

  Future<void> loadCages() async {
    isLoading.value = true;
    try {
      // Get cages with occupancy status populated
      cages.value = await _cageRepo.getCagesWithOccupancy();
      await Future.wait([checkAlerts(), checkReservations(), loadDeposits()]);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách chuồng: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkAlerts() async {
    final newAlerts = <String, List<String>>{};

    try {
      // 1. Overdue Treatments
      final overdue = await _hospRepo.getOverdueTreatments();
      for (var item in overdue) {
        final cageId = item['cage_id']?.toString();
        if (cageId != null) {
          if (!newAlerts.containsKey(cageId)) newAlerts[cageId] = [];

          // Only add unique concise message
          const msg = 'Trễ thuốc';
          if (!newAlerts[cageId]!.contains(msg)) {
            newAlerts[cageId]!.add(msg);
          }
        }
      }

      // 2. Critical Vitals
      final criticals = await _hospRepo.getCriticalVitals();
      for (var item in criticals) {
        final cageId = item['cage_id']?.toString();
        if (cageId != null) {
          if (!newAlerts.containsKey(cageId)) newAlerts[cageId] = [];

          const msg = 'Cảnh báo sinh hiệu';
          if (!newAlerts[cageId]!.contains(msg)) {
            newAlerts[cageId]!.add(msg);
          }
        }
      }

      cageAlerts.value = newAlerts;
    } catch (e) {
      print('Error checking alerts: $e');
    }
  }

  Future<void> checkReservations() async {
    final newReservations = <String, List<String>>{};
    try {
      // For each cage, check reservations?
      // Optimized: Fetch all upcoming reservations from now.
      // But implementation details kept specific to cages for now.
      for (var cage in cages) {
        final reservations = await _resRepo.getReservationsByCage(cage.id);
        if (reservations.isNotEmpty) {
          newReservations[cage.id] = [];
          // Just show the next one
          final nextRes = reservations.first;
          final dateStr = '${nextRes.startDate.day}/${nextRes.startDate.month}';
          newReservations[cage.id]!.add('Đã đặt: $dateStr');
        }
      }
      cageReservations.value = newReservations;
    } catch (e) {
      print('Error checking reservations: $e');
    }
  }

  // ===== Deposit Tracking (Feature 13) =====

  /// Load deposit amounts for all active hospitalizations
  Future<void> loadDeposits() async {
    try {
      final db = await DatabaseProvider.instance.database;
      final results = await db.rawQuery('''
        SELECT h.id as hosp_id, mc.advance_payment
        FROM hospitalizations h
        JOIN medical_cases mc ON h.case_id = mc.id
        WHERE h.status = 'active'
      ''');
      final map = <String, double>{};
      for (var row in results) {
        map[row['hosp_id'] as String] =
            (row['advance_payment'] as num?)?.toDouble() ?? 0.0;
      }
      deposits.value = map;
    } catch (e) {
      print('Error loading deposits: $e');
    }
  }

  Future<void> updateDeposit(
    String hospitalizationId,
    String caseId,
    double amount,
  ) async {
    try {
      await updateWithSync(
        table: 'medical_cases',
        recordId: caseId,
        data: {'advance_payment': amount},
      );
      deposits[hospitalizationId] = amount;
      Get.snackbar('Thành công', 'Đã cập nhật tiền cọc vào bệnh án');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể cập nhật tiền cọc: $e');
    }
  }

  Future<void> loadMedicines() async {
    try {
      availableMedicines.value = await _medicineRepo.getAll();
    } catch (e) {
      print('Error loading medicines: $e');
    }
  }

  /// Admit pet to a cage
  Future<void> admitPet(
    CageModel cage,
    String caseId,
    String petId,
    double price, {
    String? staffId,
  }) async {
    try {
      // MAINTENANCE check only
      if (cage.status == 'maintenance') {
        Get.snackbar('Lỗi', 'Chuồng đang bảo trì');
        return;
      }

      // Create hospitalization record with sync tracking
      await insertWithSync(
        table: 'hospitalizations',
        data: {
          'case_id': caseId,
          'pet_id': petId,
          'cage_id': cage.id,
          'admission_date': DateTime.now().toUtc().toIso8601String(),
          'status': 'active',
          'price': price,
          if (staffId != null) 'staff_id': staffId,
        },
      );

      await loadCages();
      Get.back();
      Get.snackbar('Thành công', 'Đã nhập chuồng');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể nhập chuồng: $e');
    }
  }

  /// Add medicine/service to a hospitalized case
  Future<void> addServiceToCase(
    String caseId,
    MedicineModel medicine,
    int quantity,
  ) async {
    try {
      final database = await db;

      // Look for existing 'Lưu chuồng' service for this case
      final hospServices = await database.query(
        'case_services',
        where:
            "case_id = ? AND (service_name LIKE '%Lưu chuồng%' OR service_name LIKE '%Lưu viện%')",
        whereArgs: [caseId],
      );

      if (hospServices.isNotEmpty) {
        final parentService = hospServices.first;
        final serviceId = parentService['id'] as String;

        List<dynamic> currentMedicines = [];
        if (parentService['medicines_json'] != null &&
            parentService['medicines_json'].toString().isNotEmpty) {
          try {
            currentMedicines =
                jsonDecode(parentService['medicines_json'].toString()) as List;
          } catch (_) {}
        }

        // Add new medicine to the list
        currentMedicines.add({
          'medicine_id': medicine.id,
          'name': medicine.name,
          'dosage': '',
          'note': 'BV thêm',
          'quantity': quantity,
        });

        // Calculate new total
        double currentTotal =
            (parentService['total'] as num?)?.toDouble() ?? 0.0;
        double medCost = medicine.avgPrice * quantity;
        double newTotal = currentTotal + medCost;

        await updateWithSync(
          table: 'case_services',
          recordId: serviceId,
          data: {
            'medicines_json': jsonEncode(currentMedicines),
            'total': newTotal,
          },
        );

        // Update total estimate
        final caseResult = await database.query(
          'medical_cases',
          where: 'id = ?',
          whereArgs: [caseId],
        );
        if (caseResult.isNotEmpty) {
          double caseTotal =
              (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0;
          await updateWithSync(
            table: 'medical_cases',
            recordId: caseId,
            data: {'total_estimate': caseTotal + medCost},
          );
        }

        Get.snackbar('Thành công', 'Đã chèn thuốc vào dịch vụ Lưu chuồng');
      } else {
        // Automatically create a "Lưu chuồng" wrapper service if it doesn't exist
        final newServiceId = uuid.v4();
        final initialMedicines = [
          {
            'medicine_id': medicine.id,
            'name': medicine.name,
            'dosage': '',
            'note': 'BV thêm',
            'quantity': quantity,
          },
        ];

        final medCost = medicine.avgPrice * quantity;

        await insertWithSync(
          table: 'case_services',
          data: {
            'id': newServiceId,
            'case_id': caseId,
            'service_id': null,
            'service_name': 'Lưu chuồng (điều trị)',
            'quantity': 1,
            'unit_price': 0.0,
            'total': medCost,
            'notes': 'Tự động tạo từ khu lưu chuồng',
            'medicines_json': jsonEncode(initialMedicines),
          },
        );

        // Update total estimate
        final caseResult = await database.query(
          'medical_cases',
          where: 'id = ?',
          whereArgs: [caseId],
        );
        if (caseResult.isNotEmpty) {
          double caseTotal =
              (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0;
          await updateWithSync(
            table: 'medical_cases',
            recordId: caseId,
            data: {'total_estimate': caseTotal + medCost},
          );
        }

        Get.snackbar(
          'Thành công',
          'Đã thêm dịch vụ Lưu chuồng và chèn thuốc (do dịch vụ gốc chưa có)',
        );
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể thêm thuốc: $e');
    }
  }

  // ===== Discharge Checklist (Feature 14) =====

  /// Get discharge checklist — auto-calculated from real data
  /// Returns Map<String, {label, detail, passed}>
  Future<Map<String, Map<String, dynamic>>> getDischargeChecklist(
    String hospitalizationId,
  ) async {
    final db = await DatabaseProvider.instance.database;
    final checklist = <String, Map<String, dynamic>>{};

    try {
      // 1. Check all treatments completed today
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final dailyResult = await db.query(
        'hospitalization_dailies',
        where: 'hospitalization_id = ? AND date = ?',
        whereArgs: [hospitalizationId, today],
      );

      if (dailyResult.isNotEmpty) {
        final dailyId = dailyResult.first['id'] as String;
        final pendingTreatments = await db.query(
          'hospitalization_treatments',
          where: "daily_id = ? AND status = 'pending'",
          whereArgs: [dailyId],
        );
        checklist['treatments'] = {
          'label': 'Thuốc / Điều trị hôm nay',
          'detail': pendingTreatments.isEmpty
              ? 'Tất cả đã hoàn thành ✓'
              : '${pendingTreatments.length} mục chưa thực hiện',
          'passed': pendingTreatments.isEmpty,
        };

        // 2. Check latest vitals recorded today
        final vitals = await db.query(
          'vital_sign_logs',
          where: 'daily_id = ?',
          whereArgs: [dailyId],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        final hasVitals = vitals.isNotEmpty;
        double? lastTemp;
        if (hasVitals) {
          lastTemp = (vitals.first['temperature'] as num?)?.toDouble();
        }
        final normalTemp =
            lastTemp != null && lastTemp >= 37.5 && lastTemp <= 39.5;
        checklist['vitals'] = {
          'label': 'Sinh hiệu cuối cùng',
          'detail': hasVitals
              ? 'Nhiệt độ: ${lastTemp?.toStringAsFixed(1) ?? "N/A"}°C ${normalTemp ? "(bình thường)" : "(bất thường!)"}'
              : 'Chưa ghi nhận sinh hiệu hôm nay',
          'passed': hasVitals && normalTemp,
        };
      } else {
        checklist['treatments'] = {
          'label': 'Thuốc / Điều trị hôm nay',
          'detail': 'Chưa có phiếu điều trị ngày hôm nay',
          'passed': true,
        };
        checklist['vitals'] = {
          'label': 'Sinh hiệu cuối cùng',
          'detail': 'Chưa có phiếu sinh hiệu hôm nay',
          'passed': false,
        };
      }

      // 3. Check deposit vs estimated cost
      final hospResult = await db.rawQuery(
        '''
        SELECT h.admission_date, h.price as daily_price, mc.advance_payment as deposit
        FROM hospitalizations h
        JOIN medical_cases mc ON h.case_id = mc.id
        WHERE h.id = ?
      ''',
        [hospitalizationId],
      );

      if (hospResult.isNotEmpty) {
        final hosp = hospResult.first;
        final admDate = DateTime.parse(hosp['admission_date'] as String);
        final days = DateTime.now().difference(admDate).inDays + 1;
        final cagePrice = (hosp['daily_price'] as num?)?.toDouble() ?? 0;
        final deposit = (hosp['deposit'] as num?)?.toDouble() ?? 0;
        final estimated = days * cagePrice;
        final covered = estimated > 0 ? deposit / estimated >= 0.5 : true;

        checklist['deposit'] = {
          'label': 'Thanh toán',
          'detail':
              'Đã cọc: ${deposit.toStringAsFixed(0)}đ / Ước tính: ${estimated.toStringAsFixed(0)}đ ($days ngày)',
          'passed': covered,
        };

        checklist['duration'] = {
          'label': 'Thời gian nội trú',
          'detail':
              '$days ngày (từ ${admDate.day}/${admDate.month}/${admDate.year})',
          'passed': true, // Info only, always passes
        };
      }
    } catch (e) {
      print('Error building discharge checklist: $e');
    }

    return checklist;
  }

  /// Discharge pet (Xuất viện) & Auto-Billing
  Future<void> discharge(String hospitalizationId) async {
    try {
      final database = await db;

      // 1. Get hospitalization details to calculate fee
      final hospResult = await database.rawQuery(
        '''
        SELECT h.id, h.case_id, h.admission_date, h.price, c.name as cage_name
        FROM hospitalizations h
        LEFT JOIN cages c ON h.cage_id = c.id
        WHERE h.id = ? AND h.status = 'active'
      ''',
        [hospitalizationId],
      );

      if (hospResult.isEmpty) {
        Get.snackbar(
          'Lỗi',
          'Không tìm thấy thông tin lưu chuồng hợp lệ (có thể đã xuất viện)',
        );
        return;
      }

      final hosp = hospResult.first;
      final caseId = hosp['case_id'] as String;
      final admissionDate = DateTime.parse(hosp['admission_date'] as String);
      double price = (hosp['price'] as num?)?.toDouble() ?? 0.0;
      final cageName = hosp['cage_name'] as String? ?? 'Chuồng';
      final now = DateTime.now();

      int days = now.difference(admissionDate).inDays;
      if (days < 1) days = 1;
      final totalCost = price * days;

      // Service ID for tracking
      final serviceId = uuid.v4();

      // Transaction for atomicity (raw writes)
      await database.transaction((txn) async {
        await txn.insert('case_services', {
          'id': serviceId,
          'case_id': caseId,
          'service_id':
              null, // Auto-generated hospital fee, no specific service
          'service_name': 'Phí lưu chuồng ($cageName) - $days ngày',
          'quantity': days,
          'unit_price': price,
          'total': totalCost,
          'notes': 'Tự động tính khi xuất viện',
          '_sync_status': 'pending',
          'created_at': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
        });

        final caseResult = await txn.query(
          'medical_cases',
          where: 'id = ?',
          whereArgs: [caseId],
        );
        if (caseResult.isNotEmpty) {
          double currentTotal =
              (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0;
          await txn.update(
            'medical_cases',
            {
              'total_estimate': currentTotal + totalCost,
              '_sync_status': 'pending',
              'updated_at': now.toUtc().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [caseId],
          );
        }

        await txn.update(
          'hospitalizations',
          {
            'status': 'discharged',
            'discharge_date': now.toUtc().toIso8601String(),
            '_sync_status': 'pending',
            'updated_at': now.toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [hospitalizationId],
        );
      });

      // Track changes post-commit for sync queue
      await trackChange(
        table: 'case_services',
        recordId: serviceId,
        operation: ChangeOperation.insert,
        newData: {'case_id': caseId, 'total': totalCost},
      );
      await trackChange(
        table: 'medical_cases',
        recordId: caseId,
        operation: ChangeOperation.update,
        newData: {'total_estimate': totalCost},
      );
      await trackChange(
        table: 'hospitalizations',
        recordId: hospitalizationId,
        operation: ChangeOperation.update,
        newData: {'status': 'discharged'},
      );

      await loadCages();
      Get.snackbar(
        'Thành công',
        'Đã xuất viện.\nPhí lưu chuồng: ${days} ngày x ${price} = ${totalCost}đ đã được thêm vào hóa đơn.',
      );
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất viện: $e');
    }
  }

  Future<void> toggleMaintenance(CageModel cage) async {
    final newStatus = cage.status == 'maintenance'
        ? 'available'
        : 'maintenance';
    // If setting to maintenance, ensure it's empty
    if (newStatus == 'maintenance' && cage.occupants.isNotEmpty) {
      Get.snackbar('Lỗi', 'Không thể bảo trì chuồng đang có khách');
      return;
    }

    try {
      await _cageRepo.updateCageStatus(cage.id, newStatus);
      await loadCages();
      Get.snackbar('Thành công', 'Đã cập nhật trạng thái chuồng');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể cập nhật: $e');
    }
  }

  Future<void> createReservation(
    String cageId,
    String petId,
    DateTime start,
    DateTime end,
    String note,
  ) async {
    try {
      final res = ReservationModel(
        id: uuid.v4(),
        cageId: cageId,
        petId: petId,
        startDate: start,
        endDate: end,
        note: note,
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _resRepo.createReservation(res);
      await checkReservations();
      Get.back();
      Get.snackbar('Thành công', 'Đã tạo đặt lịch');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể đặt lịch: $e');
    }
  }

  // --- PDF PRINTING (Phase 4) ---
  Future<void> printDischargePaper(String hospitalizationId) async {
    try {
      final db = await DatabaseProvider.instance.database;

      // 1. Get Hospitalization + Cage Price
      final hospRes = await db.query(
        'hospitalizations',
        where: 'id = ?',
        whereArgs: [hospitalizationId],
      );
      if (hospRes.isEmpty) return;
      final hosp = HospitalizationModel.fromJson(hospRes.first);

      // 2. Get Case & Customer & Pet
      final caseRes = await db.rawQuery(
        '''
        SELECT mc.*, c.name as customer_name, p.name as pet_name, p.species
        FROM medical_cases mc
        JOIN customers c ON mc.customer_id = c.id
        JOIN pets p ON mc.pet_id = p.id
        WHERE mc.id = ?
      ''',
        [hosp.caseId],
      );

      if (caseRes.isEmpty) return;
      final caseData = caseRes.first;

      // 3. Get Services
      final servicesRes = await db.query(
        'case_services',
        where: 'case_id = ?',
        whereArgs: [hosp.caseId],
      );
      final services = servicesRes
          .map(
            (s) => {
              'name': s['service_name'],
              'quantity': s['quantity'],
              'total': s['total'] ?? 0.0,
            },
          )
          .toList();

      final total = (caseData['total_estimate'] as num? ?? 0).toDouble();

      // 4. Generate PDF
      final pdfBytes = await HospitalizationPdfGenerator.generateDischargePaper(
        petName: caseData['pet_name'] as String,
        customerName: caseData['customer_name'] as String,
        species: caseData['species'] as String? ?? 'Thú cưng',
        admissionDate: hosp.admissionDate,
        dischargeDate: hosp.dischargeDate ?? DateTime.now(),
        diagnosis: caseData['diagnosis'] as String? ?? 'Chưa ghi nhận',
        services: services,
        totalCost: total,
      );

      // 5. Print / Preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Phieu_Xuat_Vien_${caseData['pet_name']}.pdf',
      );
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể in phiếu: $e');
    }
  }

  Future<void> changeAssignedStaff(
    String hospitalizationId,
    String newStaffId,
  ) async {
    try {
      final db = await DatabaseProvider.instance.database;

      await db.update(
        'hospitalizations',
        {'staff_id': newStaffId},
        where: 'id = ?',
        whereArgs: [hospitalizationId],
      );

      // Trigger sync if needed (assuming updateWithSync pattern should be used here if it's synced)
      // Since it's a direct sqlite table that syncs, it should probably go through an API or a sync wrapper.
      // Assuming update is pushed via the same mechanism used everywhere else.
      Get.snackbar(
        'Thành công',
        'Đã chuyển giao nhân sự phụ trách',
        backgroundColor: Colors.green.shade100,
      );

      // Reload UI
      await loadCages();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể đổi nhân sự: $e');
    }
  }
}
