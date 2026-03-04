import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../sync/sync_engine.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';

/// Widget to display cloud sync status in sidebar
class SyncStatusWidget extends StatelessWidget {
  final bool isExpanded;

  const SyncStatusWidget({super.key, this.isExpanded = true});

  @override
  Widget build(BuildContext context) {
    // Don't show if Supabase is not configured
    if (!SupabaseConfig.isConfigured) {
      return const SizedBox.shrink();
    }

    if (!Get.isRegistered<SyncEngine>()) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final engine = SyncEngine.to;
      final isSyncing = engine.status.value == SyncStatus.syncing;
      final statusText = engine.statusMessage.value;
      final pendingCount = engine.pendingChanges.value;

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 16 : 8,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withValues(alpha: 0.5),
          border: Border(
            top: BorderSide(color: AppColors.slate800.withValues(alpha: 0.3)),
          ),
        ),
        child: isExpanded
            ? _buildExpandedView(isSyncing, statusText, pendingCount)
            : _buildCollapsedView(isSyncing, pendingCount),
      );
    });
  }

  Widget _buildExpandedView(bool isSyncing, String status, int pendingCount) {
    return Row(
      children: [
        _buildSyncIcon(isSyncing, pendingCount),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSyncing ? 'Đang đồng bộ...' : 'Cloud Sync',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                pendingCount > 0 ? '$pendingCount chưa đồng bộ' : status,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Manual sync button
        if (!isSyncing)
          GestureDetector(
            onLongPress: () {
              Get.snackbar(
                'Upload tất cả',
                'Đang tải lên toàn bộ dữ liệu...',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
              SyncEngine.to.forceSync();
            },
            child: IconButton(
              icon: const Icon(
                FontAwesomeIcons.arrowsRotate,
                size: 14,
                color: Colors.white70,
              ),
              onPressed: () => SyncEngine.to.forceSync(),
              tooltip: 'Nhấn: đồng bộ | Giữ: upload tất cả',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
      ],
    );
  }

  Widget _buildCollapsedView(bool isSyncing, int pendingCount) {
    return Center(
      child: GestureDetector(
        onTap: () => SyncEngine.to.forceSync(),
        child: _buildSyncIcon(isSyncing, pendingCount),
      ),
    );
  }

  Widget _buildSyncIcon(bool isSyncing, int pendingCount) {
    Color iconColor;
    IconData icon;

    if (isSyncing) {
      iconColor = Colors.blue;
      icon = FontAwesomeIcons.arrowsRotate;
    } else if (pendingCount > 0) {
      iconColor = Colors.orange;
      icon = FontAwesomeIcons.cloudArrowUp;
    } else {
      iconColor = Colors.green;
      icon = FontAwesomeIcons.cloud;
    }

    return Stack(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: isSyncing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : FaIcon(icon, size: 14, color: iconColor),
          ),
        ),
        if (pendingCount > 0 && !isSyncing)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                pendingCount > 9 ? '9+' : pendingCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
