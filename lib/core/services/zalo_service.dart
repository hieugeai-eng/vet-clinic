import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ZaloService extends GetxService {
  static ZaloService get to => Get.find();

  /// Open Zalo chat with a phone number
  Future<void> openChat(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Số điện thoại không hợp lệ',
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    // Format phone number: remove non-digits, replace leading 0 with 84
    String formattedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '84${formattedPhone.substring(1)}';
    }

    // Try zalo:// link first (app), then fallback to web
    final Uri appUrl = Uri.parse('https://zalo.me/$formattedPhone');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Lỗi',
          'Không thể mở Zalo. Vui lòng kiểm tra lại số điện thoại hoặc cài đặt Zalo.',
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      print('Error opening Zalo: $e');
      Get.snackbar(
        'Lỗi',
        'Có lỗi xảy ra khi mở Zalo',
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  /// Share file (e.g. Excel report)
  Future<void> shareFile(String filePath, {String? text}) async {
    try {
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: text);
    } catch (e) {
      print('Error sharing file: $e');
      Get.snackbar(
        'Lỗi',
        'Không thể chia sẻ file: $e',
        backgroundColor: Colors.red.shade100,
      );
    }
  }
}
