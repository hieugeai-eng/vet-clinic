import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:meta/meta.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/clinic_model.dart';
import '../../data/models/profile_model.dart';
import 'supabase_rest_client.dart';
import 'sync_service.dart';
import 'tenant_manager.dart';
import 'permission_service.dart';
import '../../data/providers/local/database_provider.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find();

  http.Client _client = http.Client();

  // For testing
  @visibleForTesting
  set client(http.Client client) => _client = client;

  final _secureStorage = const FlutterSecureStorage();

  final RxString accessToken = ''.obs;
  final RxString refreshToken = ''.obs;
  final Rx<Map<String, dynamic>?> currentUser = Rx<Map<String, dynamic>?>(null);

  // Context
  final Rx<ProfileModel?> currentProfile = Rx<ProfileModel?>(null);
  final Rx<ClinicModel?> currentClinic = Rx<ClinicModel?>(null);

  final isLoggedIn = false.obs;

  String get _authUrl => '${SupabaseConfig.projectUrl}/auth/v1';

  Map<String, String> get _headers => {
    'apikey': SupabaseConfig.anonKey,
    'Content-Type': 'application/json',
  };

  @override
  void onInit() {
    super.onInit();
    // loadSavedSession(); // Moved to SplashController for controlled initialization
  }

  Future<void> loadSavedSession() async {
    try {
      final box = GetStorage();
      final savedToken = await _secureStorage.read(key: 'access_token');
      final savedRefreshToken = await _secureStorage.read(key: 'refresh_token');
      final savedUser = box.read('user_data');

      if (savedToken != null && savedToken.isNotEmpty) {
        accessToken.value = savedToken;
        if (savedRefreshToken != null) {
          refreshToken.value = savedRefreshToken;
        }
        // Optionally load helper fields
        if (savedUser != null) {
          currentUser.value = Map<String, dynamic>.from(savedUser);
        }

        // Verify and Load Context
        await loadContext();

        if (currentProfile.value != null) {
          isLoggedIn.value = true;
          _checkDeviceBinding(); // Check background
        }
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
      signOut();
    }
  }

  /// Sign Up (Register)
  Future<void> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_authUrl/signup'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password, 'data': data}),
      );

      if (response.statusCode >= 400) {
        throw Exception('Signup failed: ${response.body}');
      }
    } catch (e) {
      print('Signup Error: $e');
      rethrow;
    }
  }

  /// Sign In with Email/Password
  Future<void> signIn({required String email, required String password}) async {
    try {
      if (SupabaseConfig.projectUrl.isEmpty) {
        throw Exception(
          'Chưa cấu hình Supabase URL (thiếu --dart-define). Vui lòng khởi động lại app với file .env.local',
        );
      }

      final response = await _client.post(
        Uri.parse('$_authUrl/token?grant_type=password'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode >= 400) {
        throw Exception('Login failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      accessToken.value = data['access_token'];
      refreshToken.value = data['refresh_token'];
      currentUser.value = data['user'];

      // Persist Session
      final box = GetStorage();
      await _secureStorage.write(key: 'access_token', value: accessToken.value);
      await _secureStorage.write(
        key: 'refresh_token',
        value: refreshToken.value,
      );
      box.write('user_data', currentUser.value);

      // Đóng kết nối DB hiện tại (nếu có) để các truy vấn tiếp theo mở Database của user này
      try {
        await DatabaseProvider.instance.closeDatabase();
      } catch (e) {
        print('Error closing local db after login: $e');
      }

      await loadContext();

      // Security: Device Binding Check
      await _checkDeviceBinding();

      isLoggedIn.value = true;

      // Trigger Initial Sync
      if (Get.isRegistered<SyncService>()) {
        // Run in background so we don't block UI transition
        Get.find<SyncService>().syncAll();
      }
    } catch (e) {
      print('Login Error: $e');
      rethrow;
    }
  }

  /// Get or Generate Device ID (stored locally)
  String get _deviceId {
    final box = GetStorage();
    if (box.hasData('device_id')) {
      return box.read('device_id');
    }
    final newId = const Uuid().v4();
    box.write('device_id', newId);
    return newId;
  }

  /// Check if device is approved for this clinic
  Future<void> _checkDeviceBinding() async {
    final clinicId = currentProfile.value?.clinicId;
    if (clinicId == null || clinicId.isEmpty) return;

    final deviceId = _deviceId;
    final userRole = currentProfile.value?.role ?? '';

    // Clinic owners (admin/clinic_owner) auto-approve their own devices
    final isOwner = userRole == 'admin' || userRole == 'clinic_owner';

    try {
      final devices = await SupabaseRestClient.to.get(
        'clinic_devices',
        query: {'clinic_id': 'eq.$clinicId', 'device_id': 'eq.$deviceId'},
      );

      if (devices.isEmpty) {
        // First time -> Register Device (auto-approve if owner)
        await SupabaseRestClient.to.post('clinic_devices', {
          'clinic_id': clinicId,
          'device_id': deviceId,
          'device_name': Platform.operatingSystem,
          'is_approved': isOwner, // Auto-approve for owners
          'last_active_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (!isOwner) {
          throw Exception(
            'Thiết bị mới ("$deviceId"). Vui lòng nhờ Chủ phòng khám duyệt!',
          );
        }
        // Owner: device auto-approved, continue login
      } else {
        final device = devices.first;
        final isApproved =
            device['is_approved'] == true || device['is_approved'] == 1;

        if (!isApproved) {
          if (isOwner) {
            // Auto-approve for owner if somehow unapproved
            await SupabaseRestClient.to.patch(
              'clinic_devices',
              {
                'is_approved': true,
                'last_active_at': DateTime.now().toUtc().toIso8601String(),
              },
              query: {'id': 'eq.${device['id']}'},
            );
          } else {
            throw Exception(
              'Thiết bị chưa được duyệt. Vui lòng liên hệ quản lý.',
            );
          }
        }

        // Update activity
        await SupabaseRestClient.to.patch(
          'clinic_devices',
          {
            'last_active_at': DateTime.now().toUtc().toIso8601String(),
            'last_ip': 'unknown',
          },
          query: {'id': 'eq.${device['id']}'},
        );
      }
    } catch (e) {
      // Handle known error cases
      if (e.toString().contains('409') ||
          e.toString().contains('already exists')) {
        // Device registered but maybe RLS hid it or race condition.
        // We assume it's pending approval.
        throw Exception(
          'Thiết bị đang chờ duyệt! Vui lòng liên hệ quản lý (Code 409).',
        );
      }

      // If table doesn't exist yet (migration pending on cloud), skip device check
      if (e.toString().contains('PGRST205') || e.toString().contains('404')) {
        print(
          'Device Check: clinic_devices table not found on Supabase, skipping device binding.',
        );
        return; // Allow login without device check
      }

      // For approval-related errors, rethrow
      if (e.toString().contains('chưa được duyệt') ||
          e.toString().contains('Thiết bị mới')) {
        rethrow;
      }

      print('Device Check Error: $e');
      rethrow;
    }
  }

  /// Load Profile and Clinic info
  Future<void> loadContext() async {
    final userId = currentUser.value?['id'];
    if (userId == null) return;

    try {
      // Fetch Profile
      final profiles = await SupabaseRestClient.to.get(
        'profiles',
        query: {'id': 'eq.$userId'},
      );

      if (profiles.isNotEmpty) {
        currentProfile.value = ProfileModel.fromJson(profiles.first);
        // Set role in PermissionService
        if (Get.isRegistered<PermissionService>()) {
          PermissionService.to.setRole(currentProfile.value?.role);
        }
        var clinicId = currentProfile.value?.clinicId;

        // AUTO-PROVISION: Create clinic if user has none
        if (clinicId == null) {
          debugPrint('AuthService: No clinic_id — auto-provisioning...');
          clinicId = await _autoProvisionClinic(userId);
        }

        // Fetch Clinic
        if (clinicId != null) {
          final clinics = await SupabaseRestClient.to.get(
            'clinics',
            query: {'id': 'eq.$clinicId'},
          );
          if (clinics.isNotEmpty) {
            currentClinic.value = ClinicModel.fromJson(clinics.first);
          }
        }
      } else {
        // No profile exists — create one
        debugPrint('AuthService: No profile found — creating...');
        final email = currentUser.value?['email'] ?? '';
        final userName =
            currentUser.value?['user_metadata']?['owner_name'] ??
            email.split('@').first;

        // Check if user already owns a clinic (e.g. registered from web)
        final existingClinics = await SupabaseRestClient.to.get(
          'clinics',
          query: {'owner_id': 'eq.$userId'},
        );

        String? clinicId;
        if (existingClinics.isNotEmpty) {
          clinicId = existingClinics.first['id'];
          debugPrint('AuthService: Found existing clinic $clinicId for user');
        }

        await SupabaseRestClient.to.upsert('profiles', {
          'id': userId,
          'full_name': userName,
          'role': 'admin',
          if (clinicId != null) 'clinic_id': clinicId,
        });

        // Only auto-provision if no clinic found
        if (clinicId == null) {
          clinicId = await _autoProvisionClinic(userId);
        } else {
          // Update profile with existing clinic_id
          await SupabaseRestClient.to.patch(
            'profiles',
            {'clinic_id': clinicId},
            query: {'id': 'eq.$userId'},
          );
        }

        // Re-fetch profile
        final updatedProfiles = await SupabaseRestClient.to.get(
          'profiles',
          query: {'id': 'eq.$userId'},
        );
        if (updatedProfiles.isNotEmpty) {
          currentProfile.value = ProfileModel.fromJson(updatedProfiles.first);
        }

        // Load clinic
        if (clinicId != null) {
          final clinics = await SupabaseRestClient.to.get(
            'clinics',
            query: {'id': 'eq.$clinicId'},
          );
          if (clinics.isNotEmpty) {
            currentClinic.value = ClinicModel.fromJson(clinics.first);
          }
        }
      }
    } catch (e) {
      print('Context Load Error: $e');
    }
  }

  /// Auto-create a clinic and link to user's profile
  Future<String?> _autoProvisionClinic(String userId) async {
    try {
      // First check if user already has a clinic (registered from web)
      final existing = await SupabaseRestClient.to.get(
        'clinics',
        query: {'owner_id': 'eq.$userId'},
      );

      if (existing.isNotEmpty) {
        final clinicId = existing.first['id'];
        debugPrint(
          'AuthService: Found existing clinic $clinicId, skipping creation',
        );
        await SupabaseRestClient.to.patch(
          'profiles',
          {'clinic_id': clinicId, 'role': 'admin'},
          query: {'id': 'eq.$userId'},
        );
        return clinicId;
      }

      final clinicId = const Uuid().v4();

      // 1. Create clinic
      await SupabaseRestClient.to.upsert('clinics', {
        'id': clinicId,
        'name': 'PetClinic',
        'owner_id': userId,
        'subscription_plan': 'free',
        'is_active': true,
      });
      debugPrint('AuthService: Created clinic $clinicId');

      // 2. Update profile with clinic_id
      await SupabaseRestClient.to.patch(
        'profiles',
        {'clinic_id': clinicId, 'role': 'admin'},
        query: {'id': 'eq.$userId'},
      );
      debugPrint('AuthService: Updated profile with clinic_id');

      // 3. Reload TenantManager
      if (Get.isRegistered<TenantManager>()) {
        await TenantManager.to.reloadTenant();
      }

      return clinicId;
    } catch (e) {
      debugPrint('AuthService: Auto-provision failed - $e');
      return null;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      // Save email before clearing so login form can pre-fill it
      final box = GetStorage();
      final userData = currentUser.value;
      if (userData != null && userData['email'] != null) {
        box.write('last_login_email', userData['email']);
      }

      if (accessToken.isNotEmpty) {
        await _client.post(
          Uri.parse('$_authUrl/logout'),
          headers: {
            ..._headers,
            'Authorization': 'Bearer ${accessToken.value}',
          },
        );
      }
    } catch (e) {
      print('Signout warning: $e');
    } finally {
      accessToken.value = '';
      refreshToken.value = '';
      currentUser.value = null;
      currentProfile.value = null;
      currentClinic.value = null;
      isLoggedIn.value = false;

      final box = GetStorage();
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
      box.remove('user_data');

      // Đóng local database (không xóa) để đổi tài khoản an toàn
      try {
        await DatabaseProvider.instance.closeDatabase();
      } catch (e) {
        print('Error closing local db on signout: $e');
      }
    }
  }

  /// Refresh Access Token using Refresh Token
  Future<void> recoverSession() async {
    final rToken = refreshToken.value;
    if (rToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    try {
      final response = await _client.post(
        Uri.parse('$_authUrl/token?grant_type=refresh_token'),
        headers: _headers,
        body: jsonEncode({'refresh_token': rToken}),
      );

      if (response.statusCode >= 400) {
        // If refresh fails (e.g. revoked), sign out
        if (response.statusCode == 400 || response.statusCode == 401) {
          await signOut();
        }
        throw Exception('Refresh failed: ${response.body}');
      }

      final data = jsonDecode(response.body);

      // Update tokens
      accessToken.value = data['access_token'];
      refreshToken.value = data['refresh_token'];

      // Persist
      final box = GetStorage();
      await _secureStorage.write(key: 'access_token', value: accessToken.value);
      await _secureStorage.write(
        key: 'refresh_token',
        value: refreshToken.value,
      );

      debugPrint('AuthService: Session refreshed successfully');
    } catch (e) {
      debugPrint('AuthService: Refresh error - $e');
      rethrow;
    }
  }
}
