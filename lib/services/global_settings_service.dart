import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../data/providers/local/database_provider.dart';

class GlobalSettingsService extends GetxService {
  static GlobalSettingsService get to => Get.find();

  final clinicName = 'PetClinic'.obs;
  final clinicAddress = ''.obs;
  final clinicPhone = ''.obs;
  final clinicLogoPath = RxnString();

  // Zalo OA Settings
  final zaloAppId = ''.obs;
  final zaloSecretKey = ''.obs;
  final zaloOaId = ''.obs;
  final zaloRefreshToken = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final db = await DatabaseProvider.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('settings');

      final Map<String, String> settings = {
        for (var item in maps) item['key'] as String: item['value'] as String,
      };

      if (settings['clinic_name'] != null &&
          settings['clinic_name']!.isNotEmpty) {
        clinicName.value = settings['clinic_name']!;
      }
      clinicAddress.value = settings['clinic_address'] ?? '';
      clinicPhone.value = settings['clinic_phone'] ?? '';
      clinicLogoPath.value = settings['clinic_logo_path'];

      // Zalo
      zaloAppId.value = settings['zalo_app_id'] ?? '';
      zaloSecretKey.value = settings['zalo_secret_key'] ?? '';
      zaloOaId.value = settings['zalo_oa_id'] ?? '';
      zaloRefreshToken.value = settings['zalo_refresh_token'] ?? '';
    } catch (e) {
      debugPrint('Error loading global settings: $e');
    }
  }

  Future<void> updateSettings({
    required String name,
    required String address,
    required String phone,
    String? logoPath,
    String? zaloAppId,
    String? zaloSecretKey,
    String? zaloOaId,
    String? zaloRefreshToken,
  }) async {
    try {
      final db = await DatabaseProvider.instance.database;
      final batch = db.batch();

      batch.insert('settings', {
        'key': 'clinic_name',
        'value': name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('settings', {
        'key': 'clinic_address',
        'value': address,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('settings', {
        'key': 'clinic_phone',
        'value': phone,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (logoPath != null) {
        batch.insert('settings', {
          'key': 'clinic_logo_path',
          'value': logoPath,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (zaloAppId != null) {
        batch.insert('settings', {
          'key': 'zalo_app_id',
          'value': zaloAppId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (zaloSecretKey != null) {
        batch.insert('settings', {
          'key': 'zalo_secret_key',
          'value': zaloSecretKey,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (zaloOaId != null) {
        batch.insert('settings', {
          'key': 'zalo_oa_id',
          'value': zaloOaId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (zaloRefreshToken != null) {
        batch.insert('settings', {
          'key': 'zalo_refresh_token',
          'value': zaloRefreshToken,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit();

      // Update local state
      clinicName.value = name;
      clinicAddress.value = address;
      clinicPhone.value = phone;
      if (logoPath != null) clinicLogoPath.value = logoPath;

      if (zaloAppId != null) this.zaloAppId.value = zaloAppId;
      if (zaloSecretKey != null) this.zaloSecretKey.value = zaloSecretKey;
      if (zaloOaId != null) this.zaloOaId.value = zaloOaId;
      if (zaloRefreshToken != null)
        this.zaloRefreshToken.value = zaloRefreshToken;
    } catch (e) {
      debugPrint('Error saving global settings: $e');
      rethrow;
    }
  }

  Map<String, String> get currentSettings => {
    'clinic_name': clinicName.value,
    'clinic_address': clinicAddress.value,
    'clinic_phone': clinicPhone.value,
    'clinic_logo_path': clinicLogoPath.value ?? '',
  };
}
