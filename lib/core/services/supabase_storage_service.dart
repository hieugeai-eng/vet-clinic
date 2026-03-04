import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import 'auth_service.dart';

/// Supabase Storage Service — upload/download/delete files via REST API
class SupabaseStorageService extends GetxService {
  static SupabaseStorageService get to => Get.find();

  static const String _bucket = 'case-attachments';
  final http.Client _client = http.Client();
  bool _bucketReady = false;

  Map<String, String> get _headers {
    final headers = {'apikey': SupabaseConfig.anonKey};
    try {
      if (Get.isRegistered<AuthService>() &&
          AuthService.to.accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${AuthService.to.accessToken.value}';
      } else {
        headers['Authorization'] = 'Bearer ${SupabaseConfig.anonKey}';
      }
    } catch (_) {
      headers['Authorization'] = 'Bearer ${SupabaseConfig.anonKey}';
    }
    return headers;
  }

  String get _storageUrl => '${SupabaseConfig.projectUrl}/storage/v1';

  /// Ensure storage bucket exists, create if not
  Future<void> _ensureBucketExists({String bucket = _bucket}) async {
    if (_bucketReady) return;

    try {
      // Check if bucket exists
      final checkUri = Uri.parse('$_storageUrl/bucket/$bucket');
      final checkResp = await _client.get(checkUri, headers: _headers);

      if (checkResp.statusCode == 200) {
        _bucketReady = true;
        debugPrint('📦 Storage: Bucket "$bucket" exists');
        return;
      }

      // Bucket not found — create it
      debugPrint('📦 Storage: Bucket "$bucket" not found, creating...');
      final createUri = Uri.parse('$_storageUrl/bucket');
      final createHeaders = Map<String, String>.from(_headers);
      createHeaders['Content-Type'] = 'application/json';

      final createResp = await _client.post(
        createUri,
        headers: createHeaders,
        body: jsonEncode({
          'id': bucket,
          'name': bucket,
          'public': true,
          'file_size_limit': 10485760, // 10MB
          'allowed_mime_types': [
            'image/jpeg',
            'image/png',
            'image/webp',
            'image/heic',
            'application/pdf',
          ],
        }),
      );

      if (createResp.statusCode >= 200 && createResp.statusCode < 300) {
        _bucketReady = true;
        debugPrint('📦 Storage: Bucket "$bucket" created successfully');
      } else if (createResp.body.contains('already exists')) {
        _bucketReady = true;
        debugPrint('📦 Storage: Bucket "$bucket" already exists');
      } else {
        debugPrint(
          '📦 Storage: Failed to create bucket: ${createResp.statusCode} - ${createResp.body}',
        );
      }
    } catch (e) {
      debugPrint('📦 Storage: Error ensuring bucket: $e');
    }
  }

  /// Upload file to Supabase Storage
  /// [storagePath] = e.g. "clinic_id/case_id/filename.jpg"
  Future<String> uploadFile({
    required String storagePath,
    required Uint8List fileBytes,
    required String contentType,
    String bucket = _bucket,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase not configured');
    }

    // Auto-create bucket if needed
    await _ensureBucketExists(bucket: bucket);

    final uri = Uri.parse('$_storageUrl/object/$bucket/$storagePath');
    final headers = Map<String, String>.from(_headers);
    headers['Content-Type'] = contentType;
    headers['x-upsert'] = 'true'; // Overwrite if exists

    final response = await _client.post(uri, headers: headers, body: fileBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return getPublicUrl(storagePath, bucket: bucket);
    } else {
      throw Exception(
        'Upload failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Upload file from local path
  Future<String> uploadFromPath({
    required String localPath,
    required String storagePath,
    required String contentType,
    String bucket = _bucket,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found: $localPath');
    }
    final bytes = await file.readAsBytes();
    return uploadFile(
      storagePath: storagePath,
      fileBytes: bytes,
      contentType: contentType,
      bucket: bucket,
    );
  }

  /// Get public URL for a file
  String getPublicUrl(String storagePath, {String bucket = _bucket}) {
    return '${SupabaseConfig.projectUrl}/storage/v1/object/public/$bucket/$storagePath';
  }

  /// Delete file from Supabase Storage
  Future<void> deleteFile(String storagePath, {String bucket = _bucket}) async {
    if (!SupabaseConfig.isConfigured) return;

    final uri = Uri.parse('$_storageUrl/object/$bucket');
    final headers = Map<String, String>.from(_headers);
    headers['Content-Type'] = 'application/json';

    final response = await _client.delete(
      uri,
      headers: headers,
      body: jsonEncode({
        'prefixes': [storagePath],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'Storage delete failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Check if Supabase Storage is available
  bool get isAvailable => SupabaseConfig.isConfigured;

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
}
