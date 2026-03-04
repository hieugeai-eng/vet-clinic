import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../data/providers/local/database_provider.dart';

class HomeController extends GetxController {
  final isLoading = false.obs;

  // Dashboard stats
  final todayCases = 0.obs;
  final todayRevenue = 0.0.obs;
  final pendingAppointments = 0.obs;
  final activeCases = 0.obs;
  final totalCustomers = 0.obs;
  final lowStockItems = 0.obs;

  // Cage/Hospitalization stats
  final occupiedCages = 0.obs;
  final totalCages = 0.obs;
  final petsInCages = 0.obs;
  final cageOverview = <Map<String, dynamic>>[].obs;

  // Recent activities
  final recentActivities = <Map<String, dynamic>>[].obs;

  // Upcoming appointments
  final upcomingAppointments = <Map<String, dynamic>>[].obs;

  // Protocol alerts - hospitalizations > 12h without care protocol
  final needsProtocolSetup = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();

    // Auto-refresh when sync finishes fetching or pushing new data
    if (Get.isRegistered<SyncEngine>()) {
      ever(SyncEngine.to.syncVersion, (_) {
        loadDashboardData();
      });
    }
  }

  Future<void> loadDashboardData() async {
    print('DEBUG_TRACE: loadDashboardData started');
    isLoading.value = true;
    try {
      print('DEBUG_TRACE: Getting database instance');
      final db = await DatabaseProvider.instance.database;
      print('DEBUG_TRACE: Database instance retrieved');
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Get current clinic_id for data isolation
      String clinicFilter = '';
      String clinicFilterAnd = '';
      final clinicId = Get.isRegistered<AuthService>()
          ? AuthService.to.currentProfile.value?.clinicId
          : null;
      if (clinicId != null) {
        clinicFilter = "AND clinic_id = '$clinicId'";
        clinicFilterAnd = "AND mc.clinic_id = '$clinicId'";
      }

      // Today's cases count
      final casesResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count FROM medical_cases 
        WHERE admission_date >= ? AND admission_date < ? AND (_is_deleted IS NULL OR _is_deleted = 0) $clinicFilter
      ''',
        [
          todayStart.toUtc().toIso8601String(),
          todayEnd.toUtc().toIso8601String(),
        ],
      );
      todayCases.value = casesResult.first['count'] as int? ?? 0;

      // Today's revenue
      final revenueResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(advance_payment), 0) as total FROM medical_cases 
        WHERE admission_date >= ? AND admission_date < ? AND (_is_deleted IS NULL OR _is_deleted = 0) $clinicFilter
      ''',
        [
          todayStart.toUtc().toIso8601String(),
          todayEnd.toUtc().toIso8601String(),
        ],
      );
      todayRevenue.value =
          (revenueResult.first['total'] as num?)?.toDouble() ?? 0;

      // Active cases
      final activeResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM medical_cases WHERE status = 'active' AND (_is_deleted IS NULL OR _is_deleted = 0) $clinicFilter
      ''');
      activeCases.value = activeResult.first['count'] as int? ?? 0;

      // Pending appointments today
      final appointmentResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count FROM appointments 
        WHERE appointment_date >= ? AND appointment_date < ?
        AND status IN ('pending', 'confirmed') $clinicFilter
      ''',
        [
          todayStart.toUtc().toIso8601String(),
          todayEnd.toUtc().toIso8601String(),
        ],
      );
      pendingAppointments.value = appointmentResult.first['count'] as int? ?? 0;

      // Total customers
      final customerResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM customers WHERE (is_active IS NULL OR is_active = 1) AND (_is_deleted IS NULL OR _is_deleted = 0) $clinicFilter
      ''');
      totalCustomers.value = customerResult.first['count'] as int? ?? 0;

      // Low stock medicines
      final stockResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM medicines 
        WHERE stock <= COALESCE(min_stock, 10) AND is_active = 1 $clinicFilter
      ''');
      lowStockItems.value = stockResult.first['count'] as int? ?? 0;

      // Recent activities (last 10 mixed)
      final activities = await db.rawQuery('''
        SELECT 
          mc.id as ref_id, 
          'medical_case' as activity_type, 
          mc.admission_date as activity_date, 
          c.name as customer_name, 
          p.name as pet_name, 
          'Ca khám mới: ' || IFNULL(p.name, 'Pet') as title,
          mc.case_code as reference_code
        FROM medical_cases mc
        LEFT JOIN customers c ON mc.customer_id = c.id
        LEFT JOIN pets p ON mc.pet_id = p.id
        WHERE (mc._is_deleted IS NULL OR mc._is_deleted = 0) $clinicFilterAnd
        
        UNION ALL
        
        SELECT 
          ps.id as ref_id,
          'product_sale' as activity_type,
          ps.sale_date as activity_date,
          c.name as customer_name,
          '' as pet_name,
          'Bán hàng: ' || ps.product_name as title,
          ps.case_code as reference_code
        FROM product_sales ps
        LEFT JOIN customers c ON ps.customer_id = c.id
        WHERE (ps._is_deleted IS NULL OR ps._is_deleted = 0) 
        ${clinicId != null ? "AND ps.clinic_id = '$clinicId'" : ""}
        
        UNION ALL
        
        SELECT 
          h.id as ref_id,
          'hospitalization' as activity_type,
          h.admission_date as activity_date,
          c.name as customer_name,
          p.name as pet_name,
          'Nhập viện: ' || IFNULL(p.name, 'Pet') as title,
          mc.case_code as reference_code
        FROM hospitalizations h
        LEFT JOIN medical_cases mc ON h.case_id = mc.id
        LEFT JOIN customers c ON mc.customer_id = c.id
        LEFT JOIN pets p ON h.pet_id = p.id
        WHERE (h._is_deleted IS NULL OR h._is_deleted = 0) 
        ${clinicId != null ? "AND h.clinic_id = '$clinicId'" : ""}
        
        UNION ALL
        
        SELECT 
          h.id as ref_id,
          'hospitalization_discharge' as activity_type,
          h.discharge_date as activity_date,
          c.name as customer_name,
          p.name as pet_name,
          'Xuất viện: ' || IFNULL(p.name, 'Pet') as title,
          mc.case_code as reference_code
        FROM hospitalizations h
        LEFT JOIN medical_cases mc ON h.case_id = mc.id
        LEFT JOIN customers c ON mc.customer_id = c.id
        LEFT JOIN pets p ON h.pet_id = p.id
        WHERE (h._is_deleted IS NULL OR h._is_deleted = 0) 
          AND h.status = 'completed' AND h.discharge_date IS NOT NULL
        ${clinicId != null ? "AND h.clinic_id = '$clinicId'" : ""}
          
        UNION ALL
        
        SELECT 
          hd.id as ref_id,
          'care_log' as activity_type,
          hd.created_at as activity_date, 
          c.name as customer_name,
          p.name as pet_name,
          'Chăm sóc nội trú: ' || IFNULL(p.name, 'Pet') as title,
          mc.case_code as reference_code
        FROM hospitalization_dailies hd
        LEFT JOIN hospitalizations h ON hd.hospitalization_id = h.id
        LEFT JOIN medical_cases mc ON h.case_id = mc.id
        LEFT JOIN customers c ON mc.customer_id = c.id
        LEFT JOIN pets p ON h.pet_id = p.id
        WHERE (hd._is_deleted IS NULL OR hd._is_deleted = 0) 
        ${clinicId != null ? "AND hd.clinic_id = '$clinicId'" : ""}
        
        ORDER BY activity_date DESC
        LIMIT 5
      ''');
      recentActivities.value = activities;

      // Upcoming appointments
      final upcomingClinicFilter = clinicId != null
          ? "AND a.clinic_id = '$clinicId'"
          : '';
      final appointments = await db.rawQuery(
        '''
        SELECT a.*, c.name as customer_name, c.phone as customer_phone, 
               p.name as pet_name
        FROM appointments a
        LEFT JOIN customers c ON a.customer_id = c.id
        LEFT JOIN pets p ON a.pet_id = p.id
        WHERE a.appointment_date >= ?
        AND a.status IN ('pending', 'confirmed') 
        AND (a._is_deleted IS NULL OR a._is_deleted = 0)
        $upcomingClinicFilter
        ORDER BY a.appointment_date ASC
        LIMIT 5
      ''',
        [now.toUtc().toIso8601String()],
      );
      upcomingAppointments.value = appointments;

      // Cage/Hospitalization overview
      await _loadCageOverview(db, clinicId);

      // Protocol alerts: active hospitalizations > 12h without treatments
      await _loadProtocolAlerts(db, clinicId);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải dữ liệu: $e');
    } finally {
      print('DEBUG_TRACE: loadDashboardData finished');
      isLoading.value = false;
    }
  }

  Future<void> _loadCageOverview(dynamic db, String? clinicId) async {
    try {
      final cageFilterSimple = clinicId != null
          ? "WHERE (clinic_id = '$clinicId' OR clinic_id IS NULL)"
          : '';
      final cageFilterAliased = clinicId != null
          ? "WHERE (c.clinic_id = '$clinicId' OR c.clinic_id IS NULL)"
          : '';

      // Total cages (no alias needed)
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cages $cageFilterSimple',
      );
      totalCages.value = totalResult.first['count'] as int? ?? 0;

      // Occupied cages and pets
      final occupancyResult = await db.rawQuery('''
        SELECT c.id, c.name, c.type, c.status, c.price,
               COUNT(h.id) as pet_count,
               GROUP_CONCAT(p.name, ', ') as pet_names
        FROM cages c
        LEFT JOIN hospitalizations h ON h.cage_id = c.id AND h.status = 'active'
        LEFT JOIN pets p ON h.pet_id = p.id
        ${cageFilterAliased.isNotEmpty ? cageFilterAliased : 'WHERE 1=1'}
        GROUP BY c.id
        ORDER BY c.order_index ASC
      ''');

      int occupied = 0;
      int pets = 0;
      final overview = <Map<String, dynamic>>[];

      for (final row in occupancyResult) {
        final petCount = row['pet_count'] as int? ?? 0;
        if (petCount > 0) {
          occupied++;
          pets += petCount;
        }
        overview.add(Map<String, dynamic>.from(row));
      }

      occupiedCages.value = occupied;
      petsInCages.value = pets;
      cageOverview.value = overview;
    } catch (e) {
      print('Error loading cage overview: $e');
    }
  }

  void refresh() {
    loadDashboardData();
  }

  /// Load hospitalizations > 12h that have NO care protocol set up
  Future<void> _loadProtocolAlerts(dynamic db, String? clinicId) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 12));
      final hospFilter = clinicId != null
          ? "AND h.clinic_id = '$clinicId'"
          : '';

      final results = await db.rawQuery(
        '''
        SELECT h.id, h.admission_date, h.pet_id, h.cage_id,
               p.name as pet_name, p.species,
               c.name as cage_name
        FROM hospitalizations h
        LEFT JOIN pets p ON h.pet_id = p.id
        LEFT JOIN cages c ON h.cage_id = c.id
        LEFT JOIN hospitalization_dailies d ON d.hospitalization_id = h.id
        LEFT JOIN hospitalization_treatments t ON t.daily_id = d.id
        WHERE h.status = 'active'
          AND h.admission_date < ?
          AND (h._is_deleted IS NULL OR h._is_deleted = 0)
          $hospFilter
        GROUP BY h.id
        HAVING COUNT(t.id) = 0
        ORDER BY h.admission_date ASC
      ''',
        [cutoff.toUtc().toIso8601String()],
      );

      final alerts = <Map<String, dynamic>>[];
      for (final row in results) {
        final admDate = DateTime.parse(row['admission_date'] as String);
        final hoursAgo = DateTime.now().difference(admDate).inHours;
        alerts.add({...Map<String, dynamic>.from(row), 'hours_ago': hoursAgo});
      }
      needsProtocolSetup.value = alerts;
    } catch (e) {
      print('Error loading protocol alerts: $e');
    }
  }
}
