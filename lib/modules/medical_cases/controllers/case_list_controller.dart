import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../data/models/medical_case_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../core/services/attachment_service.dart';

class CaseListController extends GetxController {
  final isLoading = false.obs;
  final cases = <MedicalCaseModel>[].obs;
  final filteredCases = <MedicalCaseModel>[].obs;

  final searchQuery = ''.obs;
  final statusFilter = 'all'.obs;
  final dateFilter = 'all'.obs;

  // Pagination
  final currentPage = 0.obs;
  final itemsPerPage = 20;
  final hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadCases();

    // Watch filters
    ever(searchQuery, (_) => filterCases());
    ever(statusFilter, (_) => filterCases());

    // Auto-refresh when remote data changes via realtime sync
    if (Get.isRegistered<SyncEngine>()) {
      ever(Get.find<SyncEngine>().syncVersion, (_) {
        loadCases(refresh: true);
      });
    }
  }

  bool _isReloading = false;

  Future<void> loadCases({bool refresh = false}) async {
    if (refresh) {
      if (_isReloading) return; // Prevent concurrent refresh requests
      _isReloading = true;
      currentPage.value = 0;
      hasMore.value = true;
      // Do NOT cases.clear() here to prevent UI flashing
    }

    if (!refresh && (isLoading.value || !hasMore.value)) return;

    // Only show full loading if we have no data at all
    if (cases.isEmpty) {
      isLoading.value = true;
    }

    try {
      final db = await DatabaseProvider.instance.database;

      final offset = currentPage.value * itemsPerPage;
      final results = await db.rawQuery(
        '''
        SELECT mc.*, 
               COALESCE(mc.customer_name, c.name, 'KH Đã xóa') as customer_name, COALESCE(mc.customer_phone, c.phone, 'N/A') as customer_phone,
               COALESCE(mc.pet_name, p.name, 'TC Đã xóa') as pet_name, COALESCE(mc.pet_species, p.species, 'N/A') as species,
               s.name as staff_name
        FROM medical_cases mc
        LEFT JOIN customers c ON mc.customer_id = c.id
        LEFT JOIN pets p ON mc.pet_id = p.id
        LEFT JOIN staff s ON mc.staff_id = s.id
        WHERE mc._is_deleted = 0
        ORDER BY mc.admission_date DESC
        LIMIT ? OFFSET ?
      ''',
        [itemsPerPage, offset],
      );

      if (results.length < itemsPerPage) {
        hasMore.value = false;
      }

      final newCases = results.map((map) {
        return MedicalCaseModel.fromJson(map);
      }).toList();

      if (refresh) {
        cases.value = newCases;
      } else {
        // Prevent duplicate appends if offset was wrong
        final existingIds = cases.map((e) => e.id).toSet();
        final filteredNew = newCases
            .where((e) => !existingIds.contains(e.id))
            .toList();
        cases.addAll(filteredNew);
      }

      currentPage.value++;
      filterCases();
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách ca bệnh: $e');
    } finally {
      isLoading.value = false;
      if (refresh) _isReloading = false;
    }
  }

  void filterCases() {
    var filtered = cases.toList();

    // Filter by search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((c) {
        return c.caseCode.toLowerCase().contains(query);
        // Note: For full search, we'd need to store customer/pet names in the model
      }).toList();
    }

    // Filter by status
    if (statusFilter.value != 'all') {
      filtered = filtered.where((c) => c.status == statusFilter.value).toList();
    }

    filteredCases.value = filtered;
  }

  // Stats
  int get totalCount => cases.length;
  int get activeCount => cases.where((c) => c.status == 'active').length;
  int get completedCount => cases.where((c) => c.status == 'completed').length;

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void setStatusFilter(String status) {
    statusFilter.value = status;
  }

  Future<void> refresh() async {
    await loadCases(refresh: true);
  }

  Future<void> deleteCase(String id) async {
    if (!PermissionService.to.can(AppPermission.casesDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa ca bệnh',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    try {
      final db = await DatabaseProvider.instance.database;
      final now = DateTime.now().toUtc().toIso8601String();

      // Get case_services IDs before soft-delete (for sync tracking)
      final serviceRows = await db.query(
        'case_services',
        columns: ['id'],
        where: 'case_id = ?',
        whereArgs: [id],
      );

      // Soft delete (consistent with sync engine)
      await db.update(
        'medical_cases',
        {'_is_deleted': 1, 'updated_at': now, '_sync_status': 'pending'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.update(
        'case_services',
        {'_is_deleted': 1, 'updated_at': now, '_sync_status': 'pending'},
        where: 'case_id = ?',
        whereArgs: [id],
      );

      // Cascade delete attachments (local files + cloud + DB)
      if (Get.isRegistered<AttachmentService>()) {
        await AttachmentService.to.deleteByCase(id);
      }

      // Track changes for sync
      if (Get.isRegistered<SyncEngine>()) {
        final engine = SyncEngine.to;
        await engine.trackChange(
          table: 'medical_cases',
          recordId: id,
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

      cases.removeWhere((c) => c.id == id);
      filterCases();

      Get.snackbar('Thành công', 'Đã xóa ca bệnh');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa ca bệnh: $e');
    }
  }
}
