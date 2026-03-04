import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/library_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/services/permission_service.dart';

class LibraryView extends GetView<LibraryController> {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Thư Viện Dữ Liệu',
      actions: [
        IconButton(
          icon: const Icon(Icons.admin_panel_settings_rounded),
          tooltip: 'Cấu hình phân quyền',
          onPressed: controller.openPermissionsConfig,
        ),
        const SizedBox(width: 8),
      ],
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),

              // Sync Management Section
              if (Get.isRegistered<SyncEngine>() &&
                  PermissionService.to.can(AppPermission.syncView)) ...[
                _buildSyncSection(),
                const SizedBox(height: 24),
              ],

              // Category Cards
              _buildCategoryGrid(),
              const SizedBox(height: 32),

              // Recent Activities
              _buildRecentActivities(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.library_books_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhập & Xuất Dữ Liệu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Quản lý dữ liệu qua file Excel',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSection() {
    final engine = SyncEngine.to;

    return Obx(() {
      final syncStatus = engine.status.value;
      final pending = engine.pendingChanges.value;
      final isSyncing = syncStatus == SyncStatus.syncing;

      // Determine status display
      Color statusColor;
      IconData statusIcon;
      String statusText;
      String statusDesc;

      if (syncStatus == SyncStatus.offline) {
        statusColor = Colors.red;
        statusIcon = Icons.cloud_off;
        statusText = 'Ngoại tuyến';
        statusDesc = 'Không có kết nối mạng';
      } else if (syncStatus == SyncStatus.error) {
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        statusText = 'Lỗi đồng bộ';
        statusDesc = 'Đã xảy ra lỗi khi đồng bộ';
      } else if (isSyncing) {
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        statusText = 'Đang đồng bộ...';
        statusDesc = 'Đang cập nhật dữ liệu';
      } else if (pending > 0) {
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_upload;
        statusText = '$pending mục chờ đồng bộ';
        statusDesc = 'Có dữ liệu chưa được đẩy lên cloud';
      } else {
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done;
        statusText = 'Đã đồng bộ';
        statusDesc = 'Tất cả dữ liệu đã cập nhật';
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isSyncing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          )
                        : Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Đồng Bộ Dữ Liệu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusDesc,
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(height: 1, color: Colors.grey.shade200),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  final actions = [
                    _buildSyncAction(
                      icon: Icons.sync,
                      label: 'Đồng bộ ngay',
                      color: Colors.blue,
                      onTap: () {
                        engine.forceSync();
                        Get.snackbar('Đồng bộ', 'Đang kiểm tra dữ liệu...');
                      },
                    ),
                    _buildSyncAction(
                      icon: Icons.cloud_upload,
                      label: 'Đẩy tất cả',
                      color: Colors.teal,
                      onTap: () async {
                        Get.snackbar(
                          'Đang đẩy dữ liệu...',
                          'Quá trình có thể mất vài phút',
                        );
                        final report = await engine.pushAllData();
                        final buffer = StringBuffer();
                        report.forEach((table, counts) {
                          buffer.writeln(
                            '$table: ✅${counts['success']} ❌${counts['fail']} ⏭${counts['skip']}',
                          );
                        });
                        Get.defaultDialog(
                          title: 'Kết quả đẩy dữ liệu',
                          content: SizedBox(
                            width: 500,
                            height: 400,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                buffer.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    _buildSyncAction(
                      icon: Icons.bug_report,
                      label: 'Chẩn đoán',
                      color: Colors.orange,
                      onTap: () async {
                        Get.snackbar('Đang chẩn đoán...', 'Vui lòng đợi');
                        final results = await engine.diagnosePush();
                        final buffer = StringBuffer();
                        results.forEach((k, v) => buffer.writeln('$k: $v'));
                        Get.defaultDialog(
                          title: 'Kết quả chẩn đoán',
                          content: SizedBox(
                            width: 500,
                            height: 400,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                buffer.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    _buildSyncAction(
                      icon: Icons.cleaning_services,
                      label: 'Dọn Bộ Nhớ',
                      color: Colors.deepPurple,
                      onTap: () async {
                        Get.snackbar(
                          'Đang dọn dẹp...',
                          'Xóa đệm dữ liệu thừa cục bộ',
                        );
                        final report = await engine.cleanupLocal();
                        if (report.isEmpty) {
                          Get.snackbar(
                            '✅ Sạch sẽ',
                            'Không có dữ liệu rác để xóa',
                          );
                        } else {
                          final buffer = StringBuffer();
                          report.forEach((table, count) {
                            buffer.writeln('$table: xóa $count records');
                          });
                          Get.defaultDialog(
                            title: 'Kết quả dọn dẹp',
                            content: SizedBox(
                              width: 400,
                              height: 300,
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  buffer.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    if (pending > 0)
                      _buildSyncAction(
                        icon: Icons.delete_sweep,
                        label: 'Xóa hàng đợi ($pending)',
                        color: Colors.red,
                        onTap: () {
                          engine.clearPendingQueue();
                          Get.snackbar('Thành công', 'Đã xóa hàng đợi đồng bộ');
                        },
                      ),
                  ];

                  if (isNarrow) {
                    return Wrap(spacing: 8, runSpacing: 8, children: actions);
                  }
                  return Row(
                    children: actions
                        .map(
                          (a) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: a,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSyncAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = w < 600;
        final isWide = w > 900;

        if (isMobile) {
          return Column(
            children: DataCategory.values
                .map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCategoryCard(cat, w),
                  ),
                )
                .toList(),
          );
        }

        final crossAxisCount = isWide ? 4 : 2;
        // Adaptive aspect ratio: give more height when cards are narrower
        final cardWidth = (w - (crossAxisCount - 1) * 16) / crossAxisCount;
        final aspectRatio = cardWidth < 200
            ? 0.85
            : (cardWidth < 280 ? 1.2 : 2.0);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          children: DataCategory.values
              .map((cat) => _buildCategoryCard(cat, cardWidth))
              .toList(),
        );
      },
    );
  }

  Widget _buildCategoryCard(DataCategory category, double availableWidth) {
    final colors = _getCategoryColors(category);
    // Scale sizes based on available width
    final isCompact = availableWidth < 280;
    final isVeryCompact = availableWidth < 200;
    final iconSize = isVeryCompact ? 18.0 : (isCompact ? 22.0 : 28.0);
    final iconPadding = isVeryCompact ? 6.0 : (isCompact ? 8.0 : 12.0);
    final cardPadding = isVeryCompact ? 8.0 : (isCompact ? 10.0 : 16.0);
    final labelSize = isVeryCompact ? 10.0 : (isCompact ? 11.0 : 13.0);
    final countSize = isVeryCompact ? 18.0 : (isCompact ? 20.0 : 26.0);
    final actionIconSize = isVeryCompact ? 13.0 : (isCompact ? 15.0 : 18.0);
    final actionPadding = isVeryCompact ? 3.0 : (isCompact ? 4.0 : 6.0);
    final gap = isVeryCompact ? 4.0 : (isCompact ? 6.0 : 8.0);
    // Use vertical layout for very compact cards
    final useVerticalLayout = availableWidth < 300;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 20),
        boxShadow: [
          BoxShadow(
            color: colors['bg']!.withAlpha(204),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: colors['border']!.withAlpha(76)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCompact ? 12 : 20),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              if (!isVeryCompact)
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: isCompact ? 60 : 100,
                    height: isCompact ? 60 : 100,
                    decoration: BoxDecoration(
                      color: colors['bg']!.withAlpha(128),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              Padding(
                padding: EdgeInsets.all(cardPadding),
                child: useVerticalLayout
                    ? _buildVerticalCardContent(
                        category,
                        colors,
                        iconSize,
                        iconPadding,
                        labelSize,
                        countSize,
                        actionIconSize,
                        actionPadding,
                        gap,
                      )
                    : _buildHorizontalCardContent(
                        category,
                        colors,
                        iconSize,
                        iconPadding,
                        labelSize,
                        countSize,
                        actionIconSize,
                        actionPadding,
                        gap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Horizontal layout (wide cards)
  Widget _buildHorizontalCardContent(
    DataCategory category,
    Map<String, Color> colors,
    double iconSize,
    double iconPadding,
    double labelSize,
    double countSize,
    double actionIconSize,
    double actionPadding,
    double gap,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            color: colors['bg'],
            borderRadius: BorderRadius.circular(iconPadding + 4),
          ),
          child: Icon(category.icon, color: colors['icon'], size: iconSize),
        ),
        SizedBox(width: gap * 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                category.label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: gap / 2),
              Obx(
                () => Text(
                  '${controller.counts[category] ?? 0}',
                  style: TextStyle(
                    fontSize: countSize,
                    fontWeight: FontWeight.bold,
                    color: colors['text'],
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildActionButtons(
          category,
          colors,
          actionIconSize,
          actionPadding,
          gap,
        ),
      ],
    );
  }

  /// Vertical layout (narrow/compact cards)
  Widget _buildVerticalCardContent(
    DataCategory category,
    Map<String, Color> colors,
    double iconSize,
    double iconPadding,
    double labelSize,
    double countSize,
    double actionIconSize,
    double actionPadding,
    double gap,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Top row: icon + info
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: colors['bg'],
                borderRadius: BorderRadius.circular(iconPadding + 4),
              ),
              child: Icon(category.icon, color: colors['icon'], size: iconSize),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: labelSize,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Obx(
                    () => Text(
                      '${controller.counts[category] ?? 0}',
                      style: TextStyle(
                        fontSize: countSize,
                        fontWeight: FontWeight.bold,
                        color: colors['text'],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        // Bottom: action buttons wrapped
        Wrap(
          spacing: gap / 2,
          runSpacing: gap / 2,
          alignment: WrapAlignment.center,
          children: [
            _buildMiniAction(
              icon: Icons.edit_note_rounded,
              color: Colors.blue,
              onTap: () => controller.navigateToManage(category),
              tooltip: 'Quản lý',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            _buildMiniAction(
              icon: Icons.upload_file_rounded,
              color: colors['icon']!,
              onTap: () => controller.importData(category),
              tooltip: 'Nhập',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            _buildMiniAction(
              icon: Icons.file_download_outlined,
              color: Colors.blueGrey,
              onTap: () => controller.downloadTemplate(category),
              tooltip: 'Mẫu',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            _buildMiniAction(
              icon: Icons.delete_forever_rounded,
              color: Colors.red,
              onTap: () => controller.deleteAllData(category),
              tooltip: 'Xóa',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            _buildMiniAction(
              icon: Icons.download_rounded,
              color: Colors.green,
              onTap: () => controller.exportData(category),
              tooltip: 'Xuất',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
          ],
        ),
      ],
    );
  }

  /// Action buttons group for horizontal layout
  Widget _buildActionButtons(
    DataCategory category,
    Map<String, Color> colors,
    double actionIconSize,
    double actionPadding,
    double gap,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMiniAction(
              icon: Icons.edit_note_rounded,
              color: Colors.blue,
              onTap: () => controller.navigateToManage(category),
              tooltip: 'Quản lý dữ liệu',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            SizedBox(width: gap),
            _buildMiniAction(
              icon: Icons.upload_file_rounded,
              color: colors['icon']!,
              onTap: () => controller.importData(category),
              tooltip: 'Nhập',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMiniAction(
              icon: Icons.file_download_outlined,
              color: Colors.blueGrey,
              onTap: () => controller.downloadTemplate(category),
              tooltip: 'Tải mẫu Excel',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            SizedBox(width: gap),
            _buildMiniAction(
              icon: Icons.delete_forever_rounded,
              color: Colors.red,
              onTap: () => controller.deleteAllData(category),
              tooltip: 'Xóa tất cả',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
            SizedBox(width: gap),
            _buildMiniAction(
              icon: Icons.download_rounded,
              color: Colors.green,
              onTap: () => controller.exportData(category),
              tooltip: 'Xuất',
              iconSize: actionIconSize,
              padding: actionPadding,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
    double iconSize = 18,
    double padding = 6,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Obx(() {
      if (controller.recentActivities.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoạt động gần đây',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.recentActivities.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.history,
                    size: 18,
                    color: Colors.grey,
                  ),
                  title: Text(
                    controller.recentActivities[index],
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Map<String, Color> _getCategoryColors(DataCategory category) {
    switch (category) {
      case DataCategory.customers:
        return {
          'bg': Colors.blue.shade50,
          'border': Colors.blue.shade100,
          'iconBg': Colors.blue.shade100,
          'icon': Colors.blue.shade700,
          'text': Colors.blue.shade900,
        };
      case DataCategory.medicines:
        return {
          'bg': Colors.teal.shade50,
          'border': Colors.teal.shade100,
          'iconBg': Colors.teal.shade100,
          'icon': Colors.teal.shade700,
          'text': Colors.teal.shade900,
        };
      case DataCategory.products:
        return {
          'bg': Colors.orange.shade50,
          'border': Colors.orange.shade100,
          'iconBg': Colors.orange.shade100,
          'icon': Colors.orange.shade700,
          'text': Colors.orange.shade900,
        };
      case DataCategory.services:
        return {
          'bg': Colors.purple.shade50,
          'border': Colors.purple.shade100,
          'iconBg': Colors.purple.shade100,
          'icon': Colors.purple.shade700,
          'text': Colors.purple.shade900,
        };
    }
  }
}
