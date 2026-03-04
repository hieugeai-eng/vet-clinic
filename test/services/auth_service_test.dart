import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:okada_vet_clinic/core/services/auth_service.dart';
import 'package:okada_vet_clinic/core/services/supabase_rest_client.dart';
import 'package:okada_vet_clinic/data/models/profile_model.dart';
import 'package:okada_vet_clinic/data/models/clinic_model.dart';

// Mock SupabaseRestClient
class MockSupabaseRestClient extends GetxService implements SupabaseRestClient {
  final Map<String, List<Map<String, dynamic>>> mockData = {};

  @override
  Future<List<Map<String, dynamic>>> get(String table, {Map<String, String>? query}) async {
    if (mockData.containsKey(table)) {
      if (query != null && query.containsKey('id')) {
         final idVal = query['id'].toString().replaceAll('eq.', '');
         return mockData[table]!.where((element) => element['id'] == idVal).toList();
      }
      return mockData[table]!;
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> post(String table, Map<String, dynamic> data) async {
    mockData.putIfAbsent(table, () => []);
    final newData = {...data};
    if (!newData.containsKey('id')) {
      newData['id'] = 'mock_id_${DateTime.now().millisecondsSinceEpoch}';
    }
    mockData[table]!.add(newData);
    return newData;
  }
  
  @override
  Future<Map<String, dynamic>> patch(String table, Map<String, dynamic> data, {required Map<String, String> query}) async {
    // Basic mock
    return data;
  }
  
  @override
  Future<void> delete(String table, {required Map<String, String> query}) async {
    // Basic mock
  }

  @override
  Future<Map<String, dynamic>> upsert(String table, Map<String, dynamic> data, {String onConflict = 'id'}) async {
    // Basic mock
    return data;
  }
}

void main() {
  late AuthService authService;
  late MockSupabaseRestClient mockRestClient;

  setUp(() {
    Get.testMode = true;
    mockRestClient = MockSupabaseRestClient();
    Get.put<SupabaseRestClient>(mockRestClient);
    authService = AuthService();
    Get.put<AuthService>(authService);
  });

  tearDown(() {
    Get.reset();
  });

  group('AuthService Tests', () {
    test('loadContext should populate profile and clinic', () async {
      // Arrange
      const userId = 'user_123';
      const clinicId = 'clinic_456';
      
      // Mock Data
      mockRestClient.mockData['profiles'] = [
        {
          'id': userId,
          'clinic_id': clinicId,
          'full_name': 'Dr. Test',
          'role': 'vet',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }
      ];
      
      mockRestClient.mockData['clinics'] = [
        {
          'id': clinicId,
          'name': 'Okada Test Clinic',
          'address': 'Test Address',
          'license_key': 'KEY_123',
          'owner_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }
      ];

      // Simulate logged in user
      authService.currentUser.value = {'id': userId, 'email': 'test@okada.com'};

      // Act
      await authService.loadContext();

      // Assert
      expect(authService.currentProfile.value, isNotNull);
      expect(authService.currentProfile.value!.id, userId);
      expect(authService.currentProfile.value!.clinicId, clinicId);
      expect(authService.currentProfile.value!.fullName, 'Dr. Test');
      
      expect(authService.currentClinic.value, isNotNull);
      expect(authService.currentClinic.value!.id, clinicId);
      expect(authService.currentClinic.value!.name, 'Okada Test Clinic');
    });

    test('loadContext should handle missing profile gracefully', () async {
      // Arrange
      const userId = 'user_unknown';
      authService.currentUser.value = {'id': userId, 'email': 'unknown@okada.com'};
      
      // Act
      await authService.loadContext();
      
      // Assert
      expect(authService.currentProfile.value, isNull);
      expect(authService.currentClinic.value, isNull);
    });
  });
}
