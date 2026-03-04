import 'dart:convert';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/medical_case_model.dart';
import '../models/customer_model.dart';
import '../models/pet_model.dart';
import '../models/case_log_model.dart';
import '../models/service_model.dart';
import '../models/vital_signs_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/services/permission_service.dart';

class MedicalCaseRepository {
  final DatabaseProvider _dbProvider = DatabaseProvider.instance;
  final _uuid = const Uuid();

  /// Save (Create/Update) a complete case with all dependencies in a single transaction
  Future<void> saveCompleteCase({
    required CustomerModel customer,
    required PetModel pet,
    required MedicalCaseModel medicalCase,
    required List<CaseServiceModel> services,
    required VitalSignsModel? vitalSigns,
    required String? clinicId,
    Map<String, dynamic>? appointmentData,
    Map<String, dynamic>? hospitalizationData,
    List<CaseLogModel>? logs,
    String? cageIdToOccupy,
    bool isUpdate = false,
  }) async {
    final db = await _dbProvider.database;
    List<String> _deletedServiceIds = [];

    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();

      // 1. Upsert Customer
      final existingCust = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customer.id],
      );

      final custData = customer.toJson();
      custData['_sync_status'] = 'pending';
      custData['updated_at'] = now;
      if (clinicId != null && custData['clinic_id'] == null) {
        custData['clinic_id'] = clinicId;
      }

      if (existingCust.isNotEmpty) {
        await txn.update(
          'customers',
          custData,
          where: 'id = ?',
          whereArgs: [customer.id],
        );
      } else {
        custData['created_at'] = now;
        await txn.insert('customers', custData);
      }

      // 2. Upsert Pet
      final existingPet = await txn.query(
        'pets',
        where: 'id = ?',
        whereArgs: [pet.id],
      );

      final petData = pet.toJson();
      petData['_sync_status'] = 'pending';
      petData['updated_at'] = now;
      if (clinicId != null && petData['clinic_id'] == null) {
        petData['clinic_id'] = clinicId;
      }

      if (existingPet.isNotEmpty) {
        await txn.update('pets', petData, where: 'id = ?', whereArgs: [pet.id]);
      } else {
        petData['created_at'] = now;
        await txn.insert('pets', petData);
      }

      // 3. Save Case
      var caseJson = medicalCase.toJson();
      caseJson['_sync_status'] = 'pending';
      if (clinicId != null && caseJson['clinic_id'] == null) {
        caseJson['clinic_id'] = clinicId;
      }

      print(
        '[STAFF-DEBUG] saveCompleteCase - caseJson[staff_id]="${caseJson['staff_id']}", isUpdate=$isUpdate, caseId=${medicalCase.id}',
      );

      Map<String, Map<String, dynamic>> oldServicesMap = {};

      if (isUpdate) {
        caseJson.remove('created_at');
        await txn.update(
          'medical_cases',
          caseJson,
          where: 'id = ?',
          whereArgs: [medicalCase.id],
        );

        // Verify DB write
        final verify = await txn.query(
          'medical_cases',
          columns: ['staff_id'],
          where: 'id = ?',
          whereArgs: [medicalCase.id],
        );
        print(
          '[STAFF-DEBUG] saveCompleteCase - AFTER UPDATE verify: ${verify.isNotEmpty ? verify.first['staff_id'] : 'NOT FOUND'}',
        );

        // Fetch old services to find which ones are deleted and to calculate quantity diffs
        final oldServices = await txn.query(
          'case_services',
          columns: ['id', 'service_name', 'quantity', 'service_id'],
          where: 'case_id = ?',
          whereArgs: [medicalCase.id],
        );
        oldServicesMap = {
          for (var row in oldServices) row['id'] as String: row,
        };

        final newServiceIds = services.map((s) => s.id).toSet();

        for (var old in oldServices) {
          final oldId = old['id'] as String;
          if (!newServiceIds.contains(oldId)) {
            _deletedServiceIds.add(oldId);

            // Restore stock and delete product_sale if it was a Petshop item
            final serviceName = (old['service_name'] as String?) ?? '';
            if (serviceName.startsWith('Petshop: ') &&
                old['service_id'] != null) {
              final productId = old['service_id'] as String;
              final qty = (old['quantity'] as num?)?.toInt() ?? 1;

              await txn.delete(
                'product_sales',
                where: 'id = ?',
                whereArgs: [oldId],
              );

              final prodRes = await txn.query(
                'products',
                columns: ['stock'],
                where: 'id = ?',
                whereArgs: [productId],
              );
              if (prodRes.isNotEmpty) {
                final currentStock =
                    (prodRes.first['stock'] as num?)?.toInt() ?? 0;
                await txn.update(
                  'products',
                  {
                    'stock': currentStock + qty,
                    'updated_at': now,
                    '_sync_status': 'pending',
                  },
                  where: 'id = ?',
                  whereArgs: [productId],
                );
              }
            }
          }
        }

        // Delete old services
        await txn.delete(
          'case_services',
          where: 'case_id = ?',
          whereArgs: [medicalCase.id],
        );
      } else {
        await txn.insert('medical_cases', caseJson);
        print('[STAFF-DEBUG] saveCompleteCase - INSERTED new case');
      }

      // 4. Save Services
      for (final service in services) {
        final serviceData = service.toJson();
        serviceData['case_id'] = medicalCase.id;
        serviceData['_sync_status'] = 'pending'; // FIX: Add missing sync status
        serviceData['updated_at'] = now;
        if (serviceData['created_at'] == null ||
            serviceData['created_at'].toString().isEmpty) {
          serviceData['created_at'] = now;
        }
        if (clinicId != null && serviceData['clinic_id'] == null) {
          serviceData['clinic_id'] = clinicId;
        }
        await txn.insert(
          'case_services',
          serviceData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Handle Petshop item logic (stock deduction, sales log)
        if (service.serviceName.startsWith('Petshop: ')) {
          final productId = service.serviceId;
          final newQty = service.quantity;
          int oldQty = 0;

          if (isUpdate && oldServicesMap.containsKey(service.id)) {
            oldQty =
                (oldServicesMap[service.id]!['quantity'] as num?)?.toInt() ?? 0;
          }

          final diff = newQty - oldQty;

          if (diff != 0) {
            final prodRes = await txn.query(
              'products',
              columns: ['stock'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (prodRes.isNotEmpty) {
              final currentStock =
                  (prodRes.first['stock'] as num?)?.toInt() ?? 0;
              await txn.update(
                'products',
                {
                  'stock': currentStock - diff,
                  'updated_at': now,
                  '_sync_status': 'pending',
                },
                where: 'id = ?',
                whereArgs: [productId],
              );
            }
          }

          // Upsert product_sales record
          final currentStaffName = Get.isRegistered<PermissionService>()
              ? PermissionService.to.currentStaffName.value ??
                    PermissionService.to.currentStaffId.value
              : null;
          await txn.insert('product_sales', {
            'id': service.id, // Using case_service_id maps easily
            'clinic_id': clinicId,
            'product_id': productId,
            'product_name': service.serviceName
                .replaceFirst('Petshop: ', '')
                .trim(),
            'quantity': newQty,
            'unit_price': service.unitPrice,
            'total': service.unitPrice * newQty,
            'customer_id': customer.id,
            'staff_id': currentStaffName,
            'case_id': medicalCase.id,
            'case_code': medicalCase.caseCode,
            'sale_date': now,
            'payment_method':
                'medical_case', // special flag bridging case and petshop UI
            'created_at': now,
            '_sync_status': 'pending',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Map any orphaned attachments (created during draft) to this case
        await txn.update(
          'case_attachments',
          {'case_id': medicalCase.id, 'updated_at': now},
          where: 'case_service_id = ? AND (case_id = \'\' OR case_id IS NULL)',
          whereArgs: [service.id],
        );
      }

      // 5. Create/Update Appointment (Optional)
      if (appointmentData != null) {
        if (clinicId != null && appointmentData['clinic_id'] == null) {
          appointmentData['clinic_id'] = clinicId;
        }
        appointmentData['_sync_status'] = 'pending';

        // Find existing pending appointment for this pet and reason
        final existingAppts = await txn.query(
          'appointments',
          where: 'pet_id = ? AND status = ? AND reason LIKE ?',
          whereArgs: [
            pet.id,
            'pending',
            'Tái khám ca #${medicalCase.caseCode}%',
          ],
        );

        if (existingAppts.isNotEmpty) {
          final existingId = existingAppts.first['id'] as String;
          appointmentData['id'] = existingId; // reuse ID
          appointmentData.remove('created_at'); // preserve original creation
          await txn.update(
            'appointments',
            appointmentData,
            where: 'id = ?',
            whereArgs: [existingId],
          );
        } else {
          await txn.insert('appointments', appointmentData);
        }
      }

      // 6. Create Hospitalization (Optional)
      if (hospitalizationData != null) {
        final existingHosp = await txn.query(
          'hospitalizations',
          where: 'case_id = ?',
          whereArgs: [medicalCase.id],
        );

        if (existingHosp.isEmpty) {
          if (cageIdToOccupy != null) {
            await txn.update(
              'cages',
              {'status': 'occupied'},
              where: 'id = ?',
              whereArgs: [cageIdToOccupy],
            );
          }
          if (clinicId != null && hospitalizationData['clinic_id'] == null) {
            hospitalizationData['clinic_id'] = clinicId;
          }
          hospitalizationData['_sync_status'] = 'pending';
          await txn.insert('hospitalizations', hospitalizationData);
        }
      }

      // 7. Inject Case Logs (Audit Trail)
      if (logs != null && logs.isNotEmpty) {
        for (final log in logs) {
          final logData = log.toJson();
          logData['_sync_status'] = 'pending';
          if (clinicId != null && logData['clinic_id'] == null) {
            logData['clinic_id'] = clinicId;
          }
          await txn.insert('case_logs', logData);
        }
      }
    });

    // Track changes for sync (outside transaction for SyncEngine)
    if (Get.isRegistered<SyncEngine>()) {
      final engine = SyncEngine.to;

      await engine.trackChange(
        table: 'customers',
        recordId: customer.id,
        operation: isUpdate ? ChangeOperation.update : ChangeOperation.insert,
        newData: customer.toJson(),
      );

      await engine.trackChange(
        table: 'pets',
        recordId: pet.id,
        operation: isUpdate ? ChangeOperation.update : ChangeOperation.insert,
        newData: pet.toJson(),
      );

      await engine.trackChange(
        table: 'medical_cases',
        recordId: medicalCase.id,
        operation: isUpdate ? ChangeOperation.update : ChangeOperation.insert,
        newData: medicalCase.toJson(),
      );

      // Track case_services and attachments changes
      for (final service in services) {
        await engine.trackChange(
          table: 'case_services',
          recordId: service.id,
          operation: isUpdate ? ChangeOperation.update : ChangeOperation.insert,
          newData: service.toJson(),
        );

        // Track linked attachments
        try {
          final dbAsync = await _dbProvider.database;
          final attachments = await dbAsync.query(
            'case_attachments',
            where: 'case_service_id = ? AND is_active = 1 AND _is_deleted = 0',
            whereArgs: [service.id],
          );
          for (final att in attachments) {
            await engine.trackChange(
              table: 'case_attachments',
              recordId: att['id'] as String,
              operation: ChangeOperation.update,
              newData: Map<String, dynamic>.from(att),
            );
          }
        } catch (e) {
          print(
            '[SYNC-DEBUG] Failed to track attachments for service ${service.id}: $e',
          );
        }
      }

      // Track deleted services
      for (final deletedServiceId in _deletedServiceIds) {
        await engine.trackChange(
          table: 'case_services',
          recordId: deletedServiceId,
          operation: ChangeOperation.delete,
        );
      }

      if (appointmentData != null) {
        await engine.trackChange(
          table: 'appointments',
          recordId: appointmentData['id'] as String,
          operation: ChangeOperation.insert,
          newData: appointmentData,
        );
      }

      if (hospitalizationData != null) {
        await engine.trackChange(
          table: 'hospitalizations',
          recordId: hospitalizationData['id'] as String,
          operation: ChangeOperation.insert,
          newData: hospitalizationData,
        );
      }

      if (logs != null && logs.isNotEmpty) {
        for (final log in logs) {
          await engine.trackChange(
            table: 'case_logs',
            recordId: log.id,
            operation: ChangeOperation.insert,
            newData: log.toJson(),
          );
        }
      }
    }
  }
}
