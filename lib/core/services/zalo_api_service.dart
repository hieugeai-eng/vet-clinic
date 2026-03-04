import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../../services/global_settings_service.dart';

class ZaloApiService extends GetxService {
  static ZaloApiService get to => Get.find();

  final GlobalSettingsService _settings = GlobalSettingsService.to;

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Get valid access token
  Future<String?> getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now())) {
      return _accessToken;
    }

    return await _refreshAccessToken();
  }

  /// Refresh Access Token using Refresh Token
  Future<String?> _refreshAccessToken() async {
    final appId = _settings.zaloAppId.value;
    final secretKey = _settings.zaloSecretKey.value;
    final refreshToken = _settings.zaloRefreshToken.value;

    if (appId.isEmpty || secretKey.isEmpty || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://oauth.zaloapp.com/v4/oa/access_token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'secret_key': secretKey,
        },
        body: {
          'app_id': appId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null && data['error'] != 0) {
          print(
            'Zalo API Error: ${data['error_name']} - ${data['error_description']}',
          );
          return null;
        }

        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];
        final expiresIn = int.tryParse(data['expires_in'].toString()) ?? 3600;

        _accessToken = newAccessToken;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: expiresIn - 60),
        ); // Buffer 60s

        // Update refresh token in settings
        await _settings.updateSettings(
          name: _settings.clinicName.value,
          address: _settings.clinicAddress.value,
          phone: _settings.clinicPhone.value,
          zaloRefreshToken: newRefreshToken,
        );

        return newAccessToken;
      }
    } catch (e) {
      print('Error refreshing Zalo token: $e');
    }
    return null;
  }

  /// Send ZNS (Template Message)
  Future<bool> sendZNS({
    required String phone,
    required String templateId,
    required Map<String, dynamic> templateData,
  }) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      print('Cannot send ZNS: No access token');
      return false;
    }

    // Format phone (84...)
    String formattedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '84${formattedPhone.substring(1)}';
    }

    try {
      final response = await http.post(
        Uri.parse('https://business.openapi.zalo.me/message/template'),
        headers: {
          'Content-Type': 'application/json',
          'access_token': accessToken,
        },
        body: jsonEncode({
          'phone': formattedPhone,
          'template_id': templateId,
          'template_data': templateData,
          'tracking_id': 'tracking_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      final data = jsonDecode(response.body);
      if (data['error'] == 0) {
        return true;
      } else {
        print('ZNS Error: ${data['message']}');
        return false;
      }
    } catch (e) {
      print('Error sending ZNS: $e');
      return false;
    }
  }
}
