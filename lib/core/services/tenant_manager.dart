/// Tenant Manager - manages clinic context for multi-tenant isolation
///
/// Architecture: Shared schema (public) + RLS policies filtered by clinic_id
/// This service holds the current clinic context and provides access checks.
///
/// Note: All data isolation happens through PostgreSQL RLS policies using
/// get_my_clinic_id(). This manager is a Flutter-side context holder only.
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'supabase_rest_client.dart';
import 'auth_service.dart';
import '../config/supabase_config.dart';

/// Tenant Manager Service
class TenantManager extends GetxService {
  static TenantManager get to => Get.find();

  /// Current clinic ID (the tenant identifier)
  final RxnString currentClinicId = RxnString();

  /// Tenant status
  final RxBool isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeTenant();
  }

  /// Initialize tenant for current user
  Future<void> _initializeTenant() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('TenantManager: Supabase not configured, skipping');
      return;
    }

    try {
      if (!Get.isRegistered<AuthService>()) {
        debugPrint('TenantManager: AuthService not ready, waiting...');
        return;
      }

      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId == null) {
        debugPrint('TenantManager: No clinic associated with user');
        return;
      }

      currentClinicId.value = clinicId;
      isInitialized.value = true;

      debugPrint('TenantManager: Initialized for clinic $clinicId');
    } catch (e) {
      debugPrint('TenantManager: Initialization failed - $e');
    }
  }

  /// Reload tenant (call after login/profile change)
  Future<void> reloadTenant() async {
    isInitialized.value = false;
    currentClinicId.value = null;
    await _initializeTenant();
  }

  /// Check if current user has access to a specific tenant
  Future<bool> hasAccessToTenant(String clinicId) async {
    try {
      final profiles = await SupabaseRestClient.to.get(
        'profiles',
        query: {
          'clinic_id': 'eq.$clinicId',
          'id': 'eq.${AuthService.to.currentUser.value?['id']}',
        },
      );
      return profiles.isNotEmpty;
    } catch (e) {
      debugPrint('TenantManager: Access check failed - $e');
      return false;
    }
  }

  /// Get clinic info for current tenant
  Future<Map<String, dynamic>?> getClinicInfo() async {
    try {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId == null) return null;

      final clinics = await SupabaseRestClient.to.get(
        'clinics',
        query: {'id': 'eq.$clinicId'},
      );

      return clinics.isNotEmpty ? clinics.first : null;
    } catch (e) {
      debugPrint('TenantManager: Failed to get clinic info - $e');
      return null;
    }
  }
}
