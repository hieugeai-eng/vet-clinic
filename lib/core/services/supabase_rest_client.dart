import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'auth_service.dart';

import '../config/supabase_config.dart';

/// HTTP client wrapper for Supabase REST API
/// Uses pure Dart http package - no native dependencies
class SupabaseRestClient extends GetxService {
  static SupabaseRestClient get to => Get.find();

  final http.Client _client = http.Client();

  /// Common headers for all requests
  /// Common headers for all requests
  Map<String, String> get _headers {
    final headers = {
      'apikey': SupabaseConfig.anonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };

    // Add User Token if logged in
    try {
      if (Get.isRegistered<AuthService>() &&
          AuthService.to.accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${AuthService.to.accessToken.value}';
      } else {
        headers['Authorization'] = 'Bearer ${SupabaseConfig.anonKey}';
      }
    } catch (_) {
      // Fallback for when AuthService is not ready
      headers['Authorization'] = 'Bearer ${SupabaseConfig.anonKey}';
    }

    return headers;
  }

  /// Helper: Send request with auto-retry on 401
  Future<http.Response> _sendWithAuth(
    Future<http.Response> Function() requestFn,
  ) async {
    final response = await requestFn();

    // Check for 401 (Unauthorized) or JWT Expired
    if (response.statusCode == 401) {
      debugPrint('SupabaseRestClient: 401 Token Expired. Refreshing...');
      if (Get.isRegistered<AuthService>()) {
        try {
          await AuthService.to.recoverSession();
          // Retry with new token (requestFn will fetch new _headers)
          return await requestFn();
        } catch (e) {
          debugPrint('SupabaseRestClient: Session recovery failed - $e');
          return response; // Return original failure
        }
      }
    }
    return response;
  }

  /// GET request - fetch data from table
  /// [query] - Optional query params (e.g., {'id': 'eq.123'})
  Future<List<Map<String, dynamic>>> get(
    String table, {
    Map<String, String>? query,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception(
        'Supabase not configured. Please update supabase_config.dart',
      );
    }

    final uri = Uri.parse(
      '${SupabaseConfig.restUrl}/$table',
    ).replace(queryParameters: query);

    final response = await _sendWithAuth(
      () => _client.get(uri, headers: _headers),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(
        'GET $table failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// POST request - insert new record
  Future<Map<String, dynamic>> post(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase not configured');
    }

    final uri = Uri.parse('${SupabaseConfig.restUrl}/$table');

    final response = await _sendWithAuth(
      () => _client.post(uri, headers: _headers, body: jsonEncode(data)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = jsonDecode(response.body);
      if (result is List && result.isNotEmpty) {
        return result.first;
      }
      return result;
    } else {
      throw Exception(
        'POST $table failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// PATCH request - update existing record
  Future<Map<String, dynamic>> patch(
    String table,
    Map<String, dynamic> data, {
    required Map<String, String> query,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase not configured');
    }

    final uri = Uri.parse(
      '${SupabaseConfig.restUrl}/$table',
    ).replace(queryParameters: query);

    final response = await _sendWithAuth(
      () => _client.patch(uri, headers: _headers, body: jsonEncode(data)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = jsonDecode(response.body);
      if (result is List && result.isNotEmpty) {
        return result.first;
      }
      return result;
    } else {
      throw Exception(
        'PATCH $table failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// DELETE request - remove record
  Future<void> delete(
    String table, {
    required Map<String, String> query,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase not configured');
    }

    final uri = Uri.parse(
      '${SupabaseConfig.restUrl}/$table',
    ).replace(queryParameters: query);

    final response = await _sendWithAuth(
      () => _client.delete(uri, headers: _headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'DELETE $table failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Upsert - insert or update based on conflict
  Future<Map<String, dynamic>> upsert(
    String table,
    Map<String, dynamic> data, {
    String onConflict = 'id',
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase not configured');
    }

    final uri = Uri.parse('${SupabaseConfig.restUrl}/$table');

    final response = await _sendWithAuth(() {
      final headers = Map<String, String>.from(_headers);
      headers['Prefer'] = 'resolution=merge-duplicates,return=representation';

      return _client.post(uri, headers: headers, body: jsonEncode(data));
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = jsonDecode(response.body);
      if (result is List && result.isNotEmpty) {
        return result.first;
      }
      return result;
    } else {
      throw Exception(
        'UPSERT $table failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
}
