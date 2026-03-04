import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';

import '../../routes/app_routes.dart';
import '../../services/global_settings_service.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../constants/app_colors.dart';
import '../constants/permissions.dart';
import '../utils/responsive_helper.dart';

import '../utils/debug_logger.dart';
import '../../modules/home/controllers/home_controller.dart';

/// SidebarMenu widget (Redesigned according to Mockup 02)
class SidebarMenu extends StatelessWidget {
  final String currentRoute;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const SidebarMenu({
    super.key,
    required this.currentRoute,
    this.isExpanded = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    logDebug('Building SidebarMenu(expanded=$isExpanded)');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => logDebug('PostFrameCallback: SidebarMenu built'),
    );
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final width = isExpanded ? 220.0 : 70.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.slate800, // #1E293B
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Logo
          _buildHeader(),

          // Menu Categories
          Expanded(
            child: Obx(() {
              // Trigger reactivity on role change
              final _ = Get.isRegistered<PermissionService>()
                  ? PermissionService.to.currentRole.value
                  : null;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: _buildFilteredMenuItems(),
              );
            }),
          ),

          // Bottom Actions & Profile
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF334155), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(
                  icon: Icons.settings_rounded,
                  label: 'Cài Đặt',
                  route: Routes.settings,
                  canAccess:
                      Get.isRegistered<PermissionService>() &&
                      PermissionService.to.canAccessModule(AppModule.settings),
                ),

                // Switch staff (if needed, visible only in expanded? Or just an icon)
                _buildMenuItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Đổi ca',
                  route: 'switch-staff',
                  canAccess: true,
                ),

                const SizedBox(height: 4),

                // Current staff profile
                if (Get.isRegistered<PermissionService>())
                  Obx(() {
                    final name =
                        PermissionService.to.currentStaffName.value ?? '';
                    final role = PermissionService.to.currentRole.value;
                    if (name.isEmpty) return const SizedBox.shrink();

                    return InkWell(
                      onTap: () {
                        _showLogoutDialog();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isExpanded ? 10 : 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.slate900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF7C3AED),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  name
                                      .substring(0, 1)
                                      .toUpperCase()
                                      .replaceAll('B', 'BS'), // mock BS
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isExpanded) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      role.displayName,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.more_vert_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    Get.defaultDialog(
      title: 'Đăng xuất',
      middleText: 'Bạn có chắc chắn muốn đăng xuất?',
      textConfirm: 'Đồng ý',
      textCancel: 'Hủy',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.error,
      onConfirm: () async {
        Get.back(); // Close dialog
        try {
          final auth = Get.find<AuthService>();
          await auth.signOut();
          Get.offAllNamed(Routes.login);
        } catch (e) {
          debugPrint('Logout Error: $e');
        }
      },
    );
  }

  List<Widget> _buildFilteredMenuItems() {
    final ps = Get.isRegistered<PermissionService>()
        ? PermissionService.to
        : null;
    bool canAccess(AppModule m) => ps?.canAccessModule(m) ?? true;

    return [
      // CATEGORY: TỔNG QUAN
      _buildCategoryTitle('Tổng quan'),
      _buildMenuItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: Routes.home,
        canAccess: canAccess(AppModule.home),
      ),
      _buildMenuItem(
        icon: Icons.event_rounded,
        label: 'Lịch Hẹn',
        route: Routes.appointments,
        canAccess: canAccess(AppModule.appointments),
      ),

      // CATEGORY: KHÁM CHỮA BỆNH
      if (canAccess(AppModule.cases) || canAccess(AppModule.hospitalization))
        _buildCategoryTitle('Khám chữa bệnh'),
      _buildMenuItem(
        icon: Icons.medical_services_rounded,
        label: 'Ca Khám',
        route: Routes.cases,
        canAccess: canAccess(AppModule.cases),
      ),
      _buildMenuItem(
        icon: Icons.local_hospital_rounded,
        label: 'Nội Trú',
        route: Routes.hospitalization,
        canAccess: canAccess(AppModule.hospitalization),
      ),

      // CATEGORY: KHO & BÁN HÀNG
      if (canAccess(AppModule.pharmacy) || canAccess(AppModule.petshop))
        _buildCategoryTitle('Kho & Bán hàng'),
      _buildMenuItem(
        icon: Icons.medication_rounded,
        label: 'Kho Thuốc',
        route: Routes.pharmacy,
        canAccess: canAccess(AppModule.pharmacy),
      ),
      _buildMenuItem(
        icon: Icons.storefront_rounded,
        label: 'Petshop',
        route: Routes.petshop,
        canAccess: canAccess(AppModule.petshop),
      ),

      // CATEGORY: KHÁCH HÀNG
      if (canAccess(AppModule.customers)) _buildCategoryTitle('Khách hàng'),
      _buildMenuItem(
        icon: Icons.people_rounded,
        label: 'KH & Thú Cưng',
        route: Routes.customers,
        canAccess: canAccess(AppModule.customers),
      ),

      // CATEGORY: BÁO CÁO
      if (canAccess(AppModule.reports) || canAccess(AppModule.expenses))
        _buildCategoryTitle('Báo cáo'),
      _buildMenuItem(
        icon: Icons.bar_chart_rounded,
        label: 'Báo Cáo',
        route: Routes.reports,
        canAccess: canAccess(AppModule.reports),
      ),
      _buildMenuItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Chi Phí',
        route: Routes.expenses,
        canAccess: canAccess(AppModule.expenses),
      ),
    ];
  }

  Widget _buildCategoryTitle(String title) {
    if (!isExpanded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 12, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Obx(() {
        final settings = GlobalSettingsService.to;
        final name = settings.clinicName.value.isNotEmpty
            ? settings.clinicName.value
            : 'Pet Clinic';

        return Row(
          mainAxisAlignment: isExpanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🐾', style: TextStyle(fontSize: 20)),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Vet Clinic',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String route,
    required bool canAccess,
    String? badge,
  }) {
    if (!canAccess) return const SizedBox.shrink();

    final isActive =
        currentRoute == route ||
        (route != Routes.home && currentRoute.startsWith(route));

    return Tooltip(
      message: isExpanded ? '' : label,
      preferBelow: false,
      child: InkWell(
        onTap: () {
          if (route == 'logout') {
            _showLogoutDialog();
          } else if (route == 'switch-staff') {
            Get.offAllNamed(Routes.staffSelect);
          } else if (!isActive) {
            if (Get.context != null &&
                ResponsiveHelper.isMobile(Get.context!)) {
              Get.back(); // close drawer
            }
            Get.toNamed(route);
          } else if (isActive && route == Routes.home) {
            // If already on Home, clicking it again should refresh the dashboard
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().loadDashboardData();
            }
            if (Get.context != null &&
                ResponsiveHelper.isMobile(Get.context!)) {
              Get.back(); // close drawer
            }
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 10 : 0,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF94A3B8),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        // Badge component similar to design (red/amber pill)
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
