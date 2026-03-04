import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/update_service.dart';
import '../config/app_version.dart';

/// Update Dialog — shows when a new version is available
///
/// Displays version info, changelog, download progress,
/// and action buttons to update or dismiss.
class UpdateDialog {
  /// Show the update available dialog
  static void show() {
    final updateService = UpdateService.to;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.system_update, color: Colors.green.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Có bản cập nhật mới!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Obx(() {
            if (updateService.isDownloading.value) {
              return _buildDownloadingContent(updateService);
            }
            return _buildUpdateInfoContent(updateService);
          }),
        ),
        actions: [
          Obx(() {
            if (updateService.isDownloading.value) {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _startUpdate(updateService),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Cập nhật ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Build content showing update info
  static Widget _buildUpdateInfoContent(UpdateService updateService) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version comparison
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              _versionBadge('v${AppVersion.current}', Colors.grey),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
              ),
              _versionBadge('v${updateService.latestVersion.value}', Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Changelog
        if (updateService.releaseNotes.value.isNotEmpty) ...[
          const Text(
            'Nội dung cập nhật:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                updateService.releaseNotes.value,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build content showing download progress
  static Widget _buildDownloadingContent(UpdateService updateService) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Đang tải bản cập nhật...',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Obx(() => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: updateService.downloadProgress.value,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                minHeight: 8,
              ),
            )),
        const SizedBox(height: 8),
        Obx(() => Text(
              '${(updateService.downloadProgress.value * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )),
        const SizedBox(height: 8),
        Text(
          'Vui lòng không tắt ứng dụng',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
        ),
      ],
    );
  }

  /// Version badge widget
  static Widget _versionBadge(String version, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        version,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color.shade800,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Start the download and install process
  static Future<void> _startUpdate(UpdateService updateService) async {
    final filePath = await updateService.downloadUpdate();
    if (filePath != null) {
      await updateService.installUpdate(filePath);
    } else {
      Get.back();
      Get.snackbar(
        'Lỗi cập nhật',
        'Không thể tải bản cập nhật. Vui lòng thử lại sau.',
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade800,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }
}
