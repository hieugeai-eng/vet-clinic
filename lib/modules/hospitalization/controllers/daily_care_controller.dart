import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/hospitalization_models.dart';
import '../../../data/models/medicine_model.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/base_sync_repository.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/services/staff_sync_helper.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_service.dart';

class DailyCareController extends GetxController with SyncCapable {
  final uuid = const Uuid();
  final isLoading = false.obs;

  // Data for the specific hospitalization
  final currentHospitalizationId = ''.obs;
  final currentDaily = Rxn<HospitalizationDailyModel>();
  final dailyTreatments = <HospitalizationTreatmentModel>[].obs;
  final vitalLogs = <VitalSignLogModel>[].obs;

  // Date navigation
  final selectedDate = DateTime.now().obs;
  final isToday = true.obs;
  final admissionDate = Rxn<DateTime>();

  // Medicine Selection
  final _medicineRepo = MedicineRepository();
  final availableMedicines = <MedicineModel>[].obs;

  // Staff name cache for performer display
  final staffNames = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadMedicines();
    _loadStaffNames();
  }

  Future<void> _loadMedicines() async {
    availableMedicines.value = await _medicineRepo.getAll();
  }

  Future<void> _loadStaffNames() async {
    try {
      final rows = await StaffSyncHelper.loadStaffWithSync();
      final map = <String, String>{};
      for (final row in rows) {
        map[row['id'] as String] = row['name'] as String? ?? 'N/A';
      }
      staffNames.value = map;
    } catch (_) {}
  }

  Future<void> loadDaily(String hospitalizationId) async {
    currentHospitalizationId.value = hospitalizationId;
    selectedDate.value = DateTime.now();
    isToday.value = true;

    // Fetch admission date for navigation bounds
    try {
      final db = await DatabaseProvider.instance.database;
      final hospRes = await db.query(
        'hospitalizations',
        columns: ['admission_date'],
        where: 'id = ?',
        whereArgs: [hospitalizationId],
      );
      if (hospRes.isNotEmpty) {
        admissionDate.value = DateTime.parse(
          hospRes.first['admission_date'] as String,
        );
      }
    } catch (_) {}

    await _loadDailyForDate(DateTime.now(), createIfMissing: true);
  }

  Future<void> goToPreviousDay() async {
    final prev = selectedDate.value.subtract(const Duration(days: 1));
    if (admissionDate.value != null && _isBeforeDay(prev, admissionDate.value!))
      return;
    selectedDate.value = prev;
    isToday.value = false;
    await _loadDailyForDate(prev, createIfMissing: false);
  }

  Future<void> goToNextDay() async {
    final next = selectedDate.value.add(const Duration(days: 1));
    final now = DateTime.now();
    if (next.isAfter(now)) return;
    selectedDate.value = next;
    isToday.value = isSameDay(next, now);
    await _loadDailyForDate(next, createIfMissing: isToday.value);
  }

  Future<void> goToToday() async {
    selectedDate.value = DateTime.now();
    isToday.value = true;
    await _loadDailyForDate(DateTime.now(), createIfMissing: true);
  }

  Future<void> goToDate(DateTime date) async {
    final now = DateTime.now();
    if (_isAfterDay(date, now)) return;
    if (admissionDate.value != null && _isBeforeDay(date, admissionDate.value!))
      return;
    selectedDate.value = date;
    isToday.value = isSameDay(date, now);
    await _loadDailyForDate(date, createIfMissing: isToday.value);
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isBeforeDay(DateTime a, DateTime b) => DateTime(
    a.year,
    a.month,
    a.day,
  ).isBefore(DateTime(b.year, b.month, b.day));
  bool _isAfterDay(DateTime a, DateTime b) => DateTime(
    a.year,
    a.month,
    a.day,
  ).isAfter(DateTime(b.year, b.month, b.day));

  Future<void> _loadDailyForDate(
    DateTime date, {
    required bool createIfMissing,
  }) async {
    isLoading.value = true;
    try {
      final db = await DatabaseProvider.instance.database;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      var result = await db.query(
        'hospitalization_dailies',
        where: 'hospitalization_id = ? AND date = ?',
        whereArgs: [currentHospitalizationId.value, dateStr],
      );

      if (result.isNotEmpty) {
        currentDaily.value = HospitalizationDailyModel.fromJson(result.first);
      } else if (createIfMissing) {
        final newDaily = HospitalizationDailyModel(
          id: uuid.v4(),
          hospitalizationId: currentHospitalizationId.value,
          date: date,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await db.insert('hospitalization_dailies', newDaily.toJson());
        await trackChange(
          table: 'hospitalization_dailies',
          recordId: newDaily.id,
          operation: ChangeOperation.insert,
          newData: newDaily.toJson(),
        );
        currentDaily.value = newDaily;

        // --- COPY PREVIOUS DAY'S TREATMENTS ---
        final prevDailies = await db.query(
          'hospitalization_dailies',
          where: 'hospitalization_id = ? AND date < ?',
          whereArgs: [currentHospitalizationId.value, dateStr],
          orderBy: 'date DESC',
          limit: 1,
        );

        if (prevDailies.isNotEmpty) {
          final prevDailyId = prevDailies.first['id'] as String;
          final prevTreatments = await db.query(
            'hospitalization_treatments',
            where: 'daily_id = ?',
            whereArgs: [prevDailyId],
          );

          if (prevTreatments.isNotEmpty) {
            final batch = db.batch();
            final nowStr = DateTime.now().toUtc().toIso8601String();
            final List<Map<String, dynamic>> newTreatments = [];

            for (final pt in prevTreatments) {
              final newT = Map<String, dynamic>.from(pt);
              newT['id'] = uuid.v4();
              newT['daily_id'] = newDaily.id;
              newT['status'] = 'pending';
              newT['time_performed'] = null;
              newT['performer_id'] = null;
              newT['created_at'] = nowStr;
              newT['updated_at'] = nowStr;

              // CRITICAL: Reset sync flags so SyncEngine picks this up as a NEW record
              newT['synced'] = 0;
              newT['_sync_status'] = 'pending';
              newT['_version'] = 1;

              newTreatments.add(newT);
              batch.insert('hospitalization_treatments', newT);
            }
            await batch.commit();

            for (final newT in newTreatments) {
              await trackChange(
                table: 'hospitalization_treatments',
                recordId: newT['id'] as String,
                operation: ChangeOperation.insert,
                newData: newT,
              );
            }
          }
        }
      } else {
        // Past day with no records
        currentDaily.value = null;
        dailyTreatments.clear();
        vitalLogs.clear();
        return;
      }

      await _loadDetails(currentDaily.value!.id);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải tờ điều trị: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadDetails(String dailyId) async {
    final db = await DatabaseProvider.instance.database;

    // Load Treatments
    final treatmentsData = await db.query(
      'hospitalization_treatments',
      where: 'daily_id = ?',
      whereArgs: [dailyId],
      orderBy: 'time_scheduled ASC',
    );
    dailyTreatments.value = treatmentsData
        .map((e) => HospitalizationTreatmentModel.fromJson(e))
        .toList();

    // Load Vitals
    final vitalsData = await db.query(
      'vital_sign_logs',
      where: 'daily_id = ?',
      whereArgs: [dailyId],
      orderBy: 'time ASC',
    );
    vitalLogs.value = vitalsData
        .map((e) => VitalSignLogModel.fromJson(e))
        .toList();
  }

  // --- ACTIONS ---

  /// Save daily note to database
  Future<void> updateDailyNote(String note) async {
    if (currentDaily.value == null) return;
    try {
      await updateWithSync(
        table: 'hospitalization_dailies',
        recordId: currentDaily.value!.id,
        data: {'note': note},
      );
    } catch (_) {}
  }

  /// Generate scheduled times based on frequency
  List<String> _generateTimes(String? frequency) {
    switch (frequency?.toUpperCase()) {
      case 'BID':
        return ['08:00', '20:00'];
      case 'TID':
        return ['08:00', '14:00', '20:00'];
      case 'QID':
        return ['06:00', '12:00', '18:00', '24:00'];
      case 'Q4H':
        return ['06:00', '10:00', '14:00', '18:00', '22:00', '02:00'];
      case 'Q6H':
        return ['06:00', '12:00', '18:00', '00:00'];
      case 'Q8H':
        return ['06:00', '14:00', '22:00'];
      case 'Q12H':
        return ['08:00', '20:00'];
      default:
        return ['08:00']; // SID or unspecified
    }
  }

  Future<void> applyRegimen(RegimenModel regimen, {String? assigneeId}) async {
    if (currentDaily.value == null) return;

    try {
      final db = await DatabaseProvider.instance.database;
      final now = DateTime.now();
      final batch = db.batch();

      for (var item in regimen.items) {
        // Feature 9: Generate multiple treatments based on frequency
        final times = _generateTimes(item.parsedFrequency);

        for (var time in times) {
          final freqLabel = times.length > 1 ? ' [${time}]' : '';
          final treatment = HospitalizationTreatmentModel(
            id: uuid.v4(),
            dailyId: currentDaily.value!.id,
            type: item.type,
            name: '${item.name}$freqLabel',
            refId: item.refId,
            quantity: item.quantity,
            unit: item.unit,
            dosage: item.dosage,
            notes: item.note,
            timeScheduled: time,
            performerId: assigneeId,
            createdAt: now,
            updatedAt: now,
          );
          batch.insert('hospitalization_treatments', treatment.toJson());
        }
      }

      await batch.commit();

      // Track each treatment insert for sync
      for (var item in regimen.items) {
        final times = _generateTimes(item.parsedFrequency);
        for (var time in times) {
          await trackChange(
            table: 'hospitalization_treatments',
            recordId: item.refId ?? uuid.v4(),
            operation: ChangeOperation.insert,
            newData: {'daily_id': currentDaily.value!.id},
          );
        }
      }

      await _loadDetails(currentDaily.value!.id);
      Get.back(); // Close selector
      Get.snackbar('Thành công', 'Đã áp dụng phác đồ ${regimen.name}');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể áp dụng phác đồ: $e');
    }
  }

  Future<void> addSingleTreatment(
    HospitalizationTreatmentModel treatment,
  ) async {
    try {
      await insertWithSync(
        table: 'hospitalization_treatments',
        data: treatment.toJson(),
        id: treatment.id,
      );
      await _loadDetails(currentDaily.value!.id);
    } catch (e) {
      Get.snackbar('Lỗi', 'Failed to add treatment: $e');
    }
  }

  // ===== Feeding Module (Feature 10) =====

  /// Filtered list of meal-type treatments
  List<HospitalizationTreatmentModel> get feedingList =>
      dailyTreatments.where((t) => t.type == 'meal').toList();

  /// Add a feeding entry for the current daily
  Future<void> addFeedingEntry({
    required String name,
    double quantity = 1.0,
    String? unit,
    String? timeScheduled,
    String? notes,
  }) async {
    if (currentDaily.value == null) return;
    final treatment = HospitalizationTreatmentModel(
      id: uuid.v4(),
      dailyId: currentDaily.value!.id,
      type: 'meal',
      name: name,
      quantity: quantity,
      unit: unit,
      timeScheduled: timeScheduled,
      timePerformed: timeScheduled,
      status: 'done',
      performerId: getCurrentStaffId(),
      notes: notes != null && notes.isNotEmpty ? '[M]$notes' : '[M]',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await addSingleTreatment(treatment);
  }

  Future<void> addFeedingFromPetshop({
    required ProductModel product,
    int quantity = 1,
    String? timeScheduled,
    String? notes,
  }) async {
    if (currentDaily.value == null) return;
    try {
      // 1. Create meal treatment with product ref (as PENDING initially)
      final treatment = HospitalizationTreatmentModel(
        id: uuid.v4(),
        dailyId: currentDaily.value!.id,
        type: 'meal',
        name:
            '${product.name}${product.brand != null ? " (${product.brand})" : ""}',
        refId: product.id,
        quantity: quantity.toDouble(),
        unit: product.category ?? 'sp',
        dosage: '${product.salePrice.toStringAsFixed(0)}đ x $quantity',
        timeScheduled: timeScheduled,
        timePerformed: null, // Let executeTreatment handle this
        status: 'pending', // Let executeTreatment handle this
        performerId: null, // Let executeTreatment handle this
        notes: notes != null && notes.isNotEmpty ? '[M]$notes' : '[M]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save it into the database
      await addSingleTreatment(treatment);

      // 2. Delegate the actual execution (which handles stock, product_sales, case_services invoice)
      await executeTreatment(treatment, true);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể thêm từ Petshop: $e');
    }
  }

  /// Delete a pending feeding entry
  Future<void> deleteFeedingEntry(String treatmentId) async {
    try {
      await deleteWithSync(
        table: 'hospitalization_treatments',
        recordId: treatmentId,
        softDelete: false,
      );
      await _loadDetails(currentDaily.value!.id);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa bữa ăn: $e');
    }
  }

  Future<void> logVitalSign(VitalSignLogModel log) async {
    try {
      await insertWithSync(
        table: 'vital_sign_logs',
        data: log.toJson(),
        id: log.id,
      );
      await _loadDetails(currentDaily.value!.id);
      Get.back();
    } catch (e) {
      Get.snackbar('Lỗi', 'Failed to log vitals: $e');
    }
  }

  // ===== Weight Chart (Feature 15) =====

  /// Get weight history across all days of this hospitalization
  Future<List<Map<String, dynamic>>> getWeightHistory() async {
    if (currentHospitalizationId.value.isEmpty) return [];
    try {
      final db = await DatabaseProvider.instance.database;
      final results = await db.rawQuery(
        '''
        SELECT d.date, v.weight
        FROM vital_sign_logs v
        JOIN hospitalization_dailies d ON v.daily_id = d.id
        WHERE d.hospitalization_id = ?
          AND v.weight IS NOT NULL AND v.weight > 0
        ORDER BY d.date ASC, v.created_at ASC
      ''',
        [currentHospitalizationId.value],
      );

      // Group by date — take last weight per day
      final Map<String, double> byDate = {};
      for (var row in results) {
        final date = row['date'] as String;
        final weight = (row['weight'] as num).toDouble();
        byDate[date] = weight; // Overwrites → keeps latest per day
      }

      return byDate.entries
          .map((e) => {'date': e.key, 'weight': e.value})
          .toList();
    } catch (e) {
      print('Error loading weight history: $e');
      return [];
    }
  }

  Future<void> executeTreatment(
    HospitalizationTreatmentModel treatment,
    bool isChecked,
  ) async {
    final database = await db;

    // 1. Get Hospitalization -> Case ID immediately
    final hospRes = await database.query(
      'hospitalizations',
      columns: ['case_id'],
      where: 'id = ?',
      whereArgs: [currentHospitalizationId.value],
    );
    if (hospRes.isEmpty) {
      Get.snackbar('Lỗi', 'Không tìm thấy ca bệnh tương ứng');
      return;
    }
    final caseId = hospRes.first['case_id'] as String;

    if (!isChecked) {
      // === REVERT: Restore stock + Remove bill + Remove transaction ===
      try {
        if (treatment.refId != null &&
            treatment.refId!.isNotEmpty &&
            treatment.type == 'medicine') {
          // 1. Restore stock
          final medRes = await database.query(
            'medicines',
            where: 'id = ?',
            whereArgs: [treatment.refId],
          );
          if (medRes.isNotEmpty) {
            final currentStock = (medRes.first['stock'] as num? ?? 0)
                .toDouble();
            await updateWithSync(
              table: 'medicines',
              recordId: treatment.refId!,
              data: {'stock': currentStock + treatment.quantity},
            );
          }

          // 2. Remove medicine transaction
          final txnRes = await database.query(
            'medicine_transactions',
            where: 'purpose = ? AND case_id IS NOT NULL AND medicine_id = ?',
            whereArgs: ['hospital_treatment:${treatment.id}', treatment.refId],
          );
          for (final txn in txnRes) {
            await deleteWithSync(
              table: 'medicine_transactions',
              recordId: txn['id'] as String,
              softDelete: false,
            );
          }
        }

        // 3. Remove bill entry
        // First look for nested medicine in case_services
        final hospServices = await database.query(
          'case_services',
          where:
              "case_id = ? AND (service_name LIKE '%Lưu chuồng%' OR service_name LIKE '%Lưu viện%')",
          whereArgs: [caseId],
        );

        bool removedFromNested = false;
        double costToSubtract = 0.0;

        if (hospServices.isNotEmpty) {
          final parentService = hospServices.first;
          List<dynamic> currentMedicines = [];
          if (parentService['medicines_json'] != null &&
              parentService['medicines_json'].toString().isNotEmpty) {
            try {
              currentMedicines =
                  jsonDecode(parentService['medicines_json'].toString())
                      as List;
            } catch (_) {}
          }

          final initialLen = currentMedicines.length;
          currentMedicines.removeWhere(
            (m) =>
                m['ref_id'] == treatment.id ||
                m['note'] == 'Từ Phác đồ [${treatment.id}]' ||
                m['note'] == 'Daily Care [${treatment.id}]',
          );

          if (currentMedicines.length < initialLen) {
            removedFromNested = true;
            double price = 0.0;
            final medRes = await database.query(
              'medicines',
              where: 'id = ?',
              whereArgs: [treatment.refId],
            );
            if (medRes.isNotEmpty) {
              price = (medRes.first['avg_price'] as num? ?? 0.0).toDouble();
            }
            costToSubtract = (price * 1.2) * treatment.quantity;
            double currentTotal =
                (parentService['total'] as num?)?.toDouble() ?? 0.0;

            await updateWithSync(
              table: 'case_services',
              recordId: parentService['id'] as String,
              data: {
                'medicines_json': jsonEncode(currentMedicines),
                'total': currentTotal - costToSubtract,
              },
            );
          }
        }

        if (!removedFromNested) {
          // Fallback to standalone service deletion
          final billRes = await database.query(
            'case_services',
            where: 'id = ? OR notes = ? OR notes = ?',
            whereArgs: [
              treatment.id,
              'Từ Phác đồ [${treatment.id}]',
              'Daily Care [${treatment.id}]',
            ],
          );
          for (final bill in billRes) {
            costToSubtract += (bill['total'] as num?)?.toDouble() ?? 0.0;
            await deleteWithSync(
              table: 'case_services',
              recordId: bill['id'] as String,
              softDelete: false,
            );
          }
        }

        // Subtract from case total_estimate
        if (costToSubtract > 0) {
          final caseRes = await database.query(
            'medical_cases',
            where: 'id = ?',
            whereArgs: [caseId],
          );
          if (caseRes.isNotEmpty) {
            double currentEstimate =
                (caseRes.first['total_estimate'] as num?)?.toDouble() ?? 0.0;
            await updateWithSync(
              table: 'medical_cases',
              recordId: caseId,
              data: {'total_estimate': currentEstimate - costToSubtract},
            );
          }
        }

        // Rollback petshop meals
        if (treatment.type == 'meal' && treatment.refId != null) {
          await deleteWithSync(
            table: 'product_sales',
            recordId: treatment.id,
            softDelete: true,
          );
          final prodRes = await database.query(
            'products',
            where: 'id = ?',
            whereArgs: [treatment.refId],
          );
          if (prodRes.isNotEmpty) {
            final currentStock = (prodRes.first['stock'] as num? ?? 0).toInt();
            await updateWithSync(
              table: 'products',
              recordId: treatment.refId!,
              data: {'stock': currentStock + treatment.quantity.toInt()},
            );

            // Remove from bill
            await deleteWithSync(
              table: 'case_services',
              recordId: treatment.id,
              softDelete: false,
            );
            final caseResult = await database.query(
              'medical_cases',
              where: 'id = ?',
              whereArgs: [caseId],
            );
            if (caseResult.isNotEmpty) {
              double caseTotal =
                  (caseResult.first['total_estimate'] as num?)?.toDouble() ??
                  0.0;
              double itemCost =
                  ((prodRes.first['sale_price'] as num? ?? 0).toDouble() *
                  treatment.quantity);
              await updateWithSync(
                table: 'medical_cases',
                recordId: caseId,
                data: {
                  'total_estimate': (caseTotal - itemCost).clamp(
                    0.0,
                    double.infinity,
                  ),
                },
              );
            }
          }
        }

        // 4. Update status back to pending
        await updateWithSync(
          table: 'hospitalization_treatments',
          recordId: treatment.id,
          data: {'status': 'pending', 'time_performed': null},
        );

        await _loadDetails(currentDaily.value!.id);
        Get.snackbar('Đã hoàn tác', 'Đã hoàn trả kho và xóa chi phí.');
      } catch (e) {
        Get.snackbar('Lỗi', 'Không thể hoàn tác: $e');
      }
      return;
    }

    // === EXECUTE: Mark Done + Deduct Stock + Add to Bill ===
    try {
      final now = DateTime.now();

      // 2. Logic depending on type
      if (treatment.refId != null && treatment.refId!.isNotEmpty) {
        if (treatment.type == 'medicine') {
          // 2a. Check Stock & Price
          final medRes = await database.query(
            'medicines',
            where: 'id = ?',
            whereArgs: [treatment.refId],
          );
          if (medRes.isEmpty) throw 'Medicine not found';
          final med = medRes.first;
          final price = (med['avg_price'] as num? ?? 0).toDouble();

          // Bug 3 Fix: Validate stock before deducting
          final currentStock = (med['stock'] as num? ?? 0).toDouble();
          if (currentStock < treatment.quantity) {
            Get.snackbar(
              'Hết hàng',
              '${treatment.name} chỉ còn ${currentStock.toStringAsFixed(1)} trong kho (cần ${treatment.quantity})',
              backgroundColor: const Color(0xFFFFF3CD),
            );
            return;
          }

          // Deduct Stock (Bug 6 Fix: add clinic_id + track treatment ID)
          await insertWithSync(
            table: 'medicine_transactions',
            data: {
              'medicine_id': treatment.refId,
              'type': 'out',
              'quantity': treatment.quantity,
              'case_id': caseId,
              'clinic_id': _getClinicId(),
              'purpose': 'hospital_treatment:${treatment.id}',
              'transaction_date': now.toUtc().toIso8601String(),
            },
          );

          // Update Stock in Medicine Table
          await updateWithSync(
            table: 'medicines',
            recordId: treatment.refId!,
            data: {'stock': currentStock - treatment.quantity},
          );

          // Add to Bill (nested inside Lưu chuồng if possible)
          final hospServices = await database.query(
            'case_services',
            where:
                "case_id = ? AND (service_name LIKE '%Lưu chuồng%' OR service_name LIKE '%Lưu viện%')",
            whereArgs: [caseId],
          );

          double medCost = (price * 1.2) * treatment.quantity;

          if (hospServices.isNotEmpty) {
            final parentService = hospServices.first;
            final serviceId = parentService['id'] as String;

            List<dynamic> currentMedicines = [];
            if (parentService['medicines_json'] != null &&
                parentService['medicines_json'].toString().isNotEmpty) {
              try {
                currentMedicines =
                    jsonDecode(parentService['medicines_json'].toString())
                        as List;
              } catch (_) {}
            }

            currentMedicines.add({
              'medicine_id': treatment.refId,
              'name': treatment.name,
              'dosage': '',
              'note': 'Điều trị hằng ngày',
              'quantity': treatment.quantity.toInt(),
              'ref_id': treatment.id,
            });

            double currentTotal =
                (parentService['total'] as num?)?.toDouble() ?? 0.0;
            await updateWithSync(
              table: 'case_services',
              recordId: serviceId,
              data: {
                'medicines_json': jsonEncode(currentMedicines),
                'total': currentTotal + medCost,
              },
            );
          } else {
            await insertWithSync(
              table: 'case_services',
              data: {
                'id': treatment.id,
                'case_id': caseId,
                'service_id': treatment.refId,
                'service_name': treatment.name,
                'quantity': treatment.quantity.toInt(),
                'unit_price': price * 1.2,
                'total': medCost,
                'notes': 'Điều trị hằng ngày',
              },
            );
          }

          // Update total estimate
          final caseResult = await database.query(
            'medical_cases',
            where: 'id = ?',
            whereArgs: [caseId],
          );
          if (caseResult.isNotEmpty) {
            double caseTotal =
                (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0.0;
            await updateWithSync(
              table: 'medical_cases',
              recordId: caseId,
              data: {'total_estimate': caseTotal + medCost},
            );
          }
        } else if (treatment.type == 'service') {
          // 2b. Add Service to Bill
          final svcRes = await database.query(
            'services',
            where: 'id = ?',
            whereArgs: [treatment.refId],
          );
          if (svcRes.isNotEmpty) {
            final svc = svcRes.first;
            final price = (svc['base_price'] as num? ?? 0).toDouble();
            await insertWithSync(
              table: 'case_services',
              data: {
                'id': treatment.id,
                'case_id': caseId,
                'service_id': treatment.refId,
                'service_name': svc['name'],
                'quantity': treatment.quantity.toInt(),
                'unit_price': price,
                'total': price * treatment.quantity,
                'notes': 'Điều trị hằng ngày',
              },
            );
          }
        } else if (treatment.type == 'meal' && treatment.refId != null) {
          // 2c. Deduct Petshop Product Stock & Log Sale
          final prodRes = await database.query(
            'products',
            where: 'id = ?',
            whereArgs: [treatment.refId],
          );
          if (prodRes.isEmpty) throw 'Product not found';
          final prod = prodRes.first;
          final price = (prod['sale_price'] as num? ?? 0).toDouble();
          final currentStock = (prod['stock'] as num? ?? 0).toInt();

          if (currentStock < treatment.quantity) {
            Get.snackbar(
              'Hết hàng',
              'Sản phẩm ${treatment.name} chỉ còn $currentStock trong kho!',
              backgroundColor: const Color(0xFFFFF3CD),
            );
            return;
          }

          // Deduct stock
          await updateWithSync(
            table: 'products',
            recordId: treatment.refId!,
            data: {'stock': currentStock - treatment.quantity.toInt()},
          );
          // Log Sale
          String? custId;
          final hr = await database.query(
            'medical_cases',
            where: 'id = ?',
            whereArgs: [caseId],
          );
          if (hr.isNotEmpty) custId = hr.first['customer_id'] as String?;

          await insertWithSync(
            table: 'product_sales',
            data: {
              'id': treatment.id,
              'clinic_id': _getClinicId(),
              'product_id': treatment.refId,
              'product_name': treatment.name,
              'quantity': treatment.quantity.toInt(),
              'unit_price': price,
              'total': price * treatment.quantity.toInt(),
              'customer_id': custId,
              'staff_id': getCurrentStaffId(),
              'sale_date': now.toUtc().toIso8601String(),
              'payment_method': 'hospital_bill', // special flag
            },
          );

          // Add to Hospital Bill
          final itemCost = price * treatment.quantity;
          await insertWithSync(
            table: 'case_services',
            data: {
              'id': treatment.id,
              'case_id': caseId,
              'service_id': treatment.refId,
              'service_name': 'Petshop: ${treatment.name}',
              'quantity': treatment.quantity.toInt(),
              'unit_price': price,
              'total': itemCost,
              'notes': 'Lấy vào bữa ăn hằng ngày',
            },
          );

          // Update Case total
          final caseResult = await database.query(
            'medical_cases',
            where: 'id = ?',
            whereArgs: [caseId],
          );
          if (caseResult.isNotEmpty) {
            double caseTotal =
                (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0.0;
            await updateWithSync(
              table: 'medical_cases',
              recordId: caseId,
              data: {'total_estimate': caseTotal + itemCost},
            );
          }
        }
      }

      // 3. Update Status
      await updateWithSync(
        table: 'hospitalization_treatments',
        recordId: treatment.id,
        data: {
          'status': 'done',
          'time_performed':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'performer_id': getCurrentStaffId(),
        },
      );

      await _loadDetails(currentDaily.value!.id);
      Get.snackbar('Đã thực hiện', 'Đã trừ kho và thêm vào chi phí điều trị.');
    } catch (e) {
      Get.snackbar('Lỗi', 'Execution failed: $e');
    }
  }

  String? _getClinicId() {
    try {
      // Try to get clinic_id from AuthService if available
      final authService = Get.find<dynamic>(tag: 'AuthService');
      return authService?.currentProfile?.value?.clinicId;
    } catch (_) {
      return null;
    }
  }

  String? getCurrentStaffId() {
    try {
      if (Get.isRegistered<PermissionService>()) {
        final staffId = PermissionService.to.currentStaffId.value;
        if (staffId != null && staffId.isNotEmpty) {
          return staffId;
        }
      }
      if (Get.isRegistered<AuthService>()) {
        return AuthService.to.currentProfile.value?.id;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteTimelineEvent(dynamic rawData) async {
    try {
      if (rawData is HospitalizationTreatmentModel) {
        if (rawData.status == 'done') {
          await executeTreatment(
            rawData,
            false,
          ); // Hoàn tác medicine & services & petshop
        }
        await deleteWithSync(
          table: 'hospitalization_treatments',
          recordId: rawData.id,
          softDelete: false,
        );
      } else if (rawData is VitalSignLogModel) {
        await deleteWithSync(
          table: 'vital_sign_logs',
          recordId: rawData.id,
          softDelete: false,
        );
      }
      await _loadDetails(currentDaily.value!.id);
      Get.snackbar(
        'Thành công',
        'Đã xóa mục thành công',
        backgroundColor: const Color(0xFFF0FDF4),
      ); // green.shade50
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể xóa: $e',
        backgroundColor: const Color(0xFFFEF2F2),
      ); // red.shade50
    }
  }

  // --- CLIENT CONNECT (Phase 4) ---

  String generateDailyUpdateText(String petName) {
    if (currentDaily.value == null)
      return 'Chưa có thông tin điều trị hôm nay.';

    final dateStr = currentDaily.value!.date
        .toUtc()
        .toIso8601String()
        .split('T')
        .first;
    final note = currentDaily.value!.note ?? 'Ổn định.';

    // Treatments Summary
    final treatments = dailyTreatments
        .where((t) => t.status == 'done')
        .toList();
    final treatmentText = treatments.isEmpty
        ? 'Chưa thực hiện điều trị.'
        : treatments
              .map((t) => '- ${t.name}: ${t.quantity} ${t.unit ?? ''}')
              .join('\n');

    // Vitals Summary
    final vitals = vitalLogs
        .where((v) => v.temperature != null || v.weight != null)
        .toList();
    final vitalText = vitals.isEmpty
        ? 'Chưa ghi nhận sinh hiệu.'
        : vitals
              .map(
                (v) =>
                    '- ${v.time}: ${v.temperature ?? '-'}°C, ${v.weight ?? '-'}kg',
              )
              .join('\n');

    return '''
🏥 CẬP NHẬT TÌNH TRẠNG THÚ CƯNG
🐶 Bé: $petName
📅 Ngày: $dateStr

📝 Tình trạng chung:
$note

💊 Điều trị đã dùng:
$treatmentText

📊 Sinh hiệu & Cân nặng:
$vitalText

-----------------------
PetClinic
Hotline: 0912.345.678
''';
  }
}
