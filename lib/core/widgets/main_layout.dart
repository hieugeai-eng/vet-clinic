import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../constants/app_colors.dart';
import '../utils/responsive_helper.dart';
import '../utils/debug_logger.dart';
import '../services/permission_service.dart';
import '../services/auth_service.dart';
import '../constants/permissions.dart';

import 'sidebar_menu.dart';
import '../../modules/home/controllers/home_controller.dart';

/// Main layout controller
class MainLayoutController extends GetxController {
  final sidebarExpanded = true.obs;
  final currentRoute = '/home'.obs;

  void toggleSidebar() {
    sidebarExpanded.value = !sidebarExpanded.value;
  }

  void setCurrentRoute(String route) {
    currentRoute.value = route;
  }

  int get currentBottomNavIndex {
    if (currentRoute.value == Routes.home) return 0;
    if (currentRoute.value.startsWith(Routes.cases)) return 1;
    if (currentRoute.value.startsWith(Routes.hospitalization)) return 2;
    if (currentRoute.value.startsWith(Routes.pharmacy)) return 3;
    if (currentRoute.value.startsWith('/more')) return 4;
    return 0; // default
  }

  void onBottomNavTapped(int index) {
    switch (index) {
      case 0:
        if (currentRoute.value != Routes.home) {
          Get.toNamed(Routes.home);
        } else if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().loadDashboardData();
        }
        break;
      case 1:
        if (currentRoute.value != Routes.cases) Get.toNamed(Routes.cases);
        break;
      case 2:
        if (currentRoute.value != Routes.hospitalization)
          Get.toNamed(Routes.hospitalization);
        break;
      case 3:
        if (currentRoute.value != Routes.pharmacy) Get.toNamed(Routes.pharmacy);
        break;
      case 4:
        Get.bottomSheet(
          _buildMoreMenuSheet(),
          isScrollControlled: true,
          backgroundColor: Colors.white,
        );
        break;
    }
  }

  Widget _buildMoreMenuSheet() {
    // Check permissions
    final ps = Get.isRegistered<PermissionService>()
        ? PermissionService.to
        : null;
    bool canAccess(AppModule m) => ps?.canAccessModule(m) ?? true;

    // A quick menu for Mobile "More" tab so we don't need a whole new route yet.
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Menu Mở Rộng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              if (canAccess(AppModule.customers))
                _buildShortcutItem(
                  Icons.people_rounded,
                  'Khách hàng',
                  Colors.blue,
                  () {
                    Get.back();
                    Get.toNamed(Routes.customers);
                  },
                ),
              if (canAccess(AppModule.petshop))
                _buildShortcutItem(
                  Icons.storefront_rounded,
                  'Petshop',
                  Colors.orange,
                  () {
                    Get.back();
                    Get.toNamed(Routes.petshop);
                  },
                ),
              if (canAccess(AppModule.appointments))
                _buildShortcutItem(
                  Icons.calendar_month_rounded,
                  'Lịch Hẹn',
                  Colors.green,
                  () {
                    Get.back();
                    Get.toNamed(Routes.appointments);
                  },
                ),
              if (canAccess(AppModule.reports))
                _buildShortcutItem(
                  Icons.bar_chart_rounded,
                  'Báo cáo',
                  Colors.purple,
                  () {
                    Get.back();
                    Get.toNamed(Routes.reports);
                  },
                ),
              if (canAccess(AppModule.expenses))
                _buildShortcutItem(
                  Icons.account_balance_wallet_rounded,
                  'Chi phí',
                  Colors.red,
                  () {
                    Get.back();
                    Get.toNamed(Routes.expenses);
                  },
                ),
              if (canAccess(AppModule.settings))
                _buildShortcutItem(
                  Icons.settings_rounded,
                  'Cài đặt',
                  Colors.grey,
                  () {
                    Get.back();
                    Get.toNamed(Routes.settings);
                  },
                ),

              // Account Actions
              _buildShortcutItem(
                Icons.people_alt_rounded,
                'Đổi ca',
                Colors.teal,
                () {
                  Get.back();
                  Get.offAllNamed(Routes.staffSelect);
                },
              ),
              _buildShortcutItem(
                Icons.logout_rounded,
                'Đăng xuất',
                Colors.brown,
                () {
                  Get.back();
                  _showLogoutDialog();
                },
              ),
            ],
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

  Widget _buildShortcutItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Main layout widget
class MainLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool hideAppBar;
  final bool showBackButton;

  const MainLayout({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.hideAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    logDebug('Building MainLayout');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => logDebug('PostFrameCallback: MainLayout built'),
    );
    final controller = Get.put(MainLayoutController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.currentRoute.value != Get.currentRoute) {
        controller.setCurrentRoute(Get.currentRoute);
      }
    });

    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (hideAppBar || (!isMobile && !showBackButton))
          ? null
          : _buildAppBar(context, isMobile: isMobile, showMenuButton: false),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(context, controller),
        tablet: _buildDesktopLayout(context, controller, forceCollapse: true),
        desktop: _buildDesktopLayout(context, controller),
      ),
      floatingActionButton: floatingActionButton,
      drawer:
          null, // Removed mobile drawer, relying purely on bottom sheet menu
      bottomNavigationBar: isMobile ? _buildBottomNav(controller) : null,
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    MainLayoutController controller,
  ) {
    return SafeArea(child: child);
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    MainLayoutController controller, {
    bool forceCollapse = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => SidebarMenu(
            currentRoute: controller.currentRoute.value,
            isExpanded: forceCollapse
                ? false
                : controller.sidebarExpanded.value,
            onToggle: forceCollapse ? null : controller.toggleSidebar,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hideAppBar) _buildDesktopHeader(context),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      height: 57, // 56 + 1 border
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.slate800,
              ),
              onPressed: () => Get.back(),
            ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate800,
                ),
              ),
            ),
          const Spacer(),
          if (actions != null) ...actions!,
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.slate900,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required bool isMobile,
    bool showMenuButton = false,
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: isMobile,
      scrolledUnderElevation: 0,
      title: title != null
          ? Text(
              title!,
              style: TextStyle(
                fontSize: isMobile ? 17 : 19,
                fontWeight: FontWeight.bold,
                color: AppColors.slate800,
              ),
            )
          : null,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.slate800,
              ),
              onPressed: () => Get.back(),
            )
          : (showMenuButton
                ? Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.slate800,
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  )
                : null),
      actions: [if (actions != null) ...actions!],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: AppColors.border, height: 1.0),
      ),
    );
  }

  Widget _buildMobileDrawer(MainLayoutController controller) {
    return Drawer(
      backgroundColor: AppColors.slate800,
      child: Obx(
        () => SidebarMenu(
          currentRoute: controller.currentRoute.value,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildBottomNav(MainLayoutController controller) {
    return Obx(() {
      return Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: controller.currentBottomNavIndex,
          onTap: controller.onBottomNavTapped,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.slate600,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Tổng Quan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_rounded),
              label: 'Ca Khám',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital_rounded),
              label: 'Nội Trú',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_rounded),
              label: 'Kho Thuốc',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'Thêm',
            ),
          ],
        ),
      );
    });
  }
}
