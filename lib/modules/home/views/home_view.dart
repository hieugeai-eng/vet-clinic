import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../routes/app_routes.dart';
import '../controllers/home_controller.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../data/models/medical_case_model.dart'; // Added for routing arguments
import '../../../data/models/appointment_model.dart'; // Added for routing arguments

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    logDebug('Building HomeView');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => logDebug('PostFrameCallback: HomeView built'),
    );
    // Ensure controller is initialized
    Get.put(HomeController());

    return MainLayout(
      title: 'Trang Chủ',
      hideAppBar: true,
      child: RefreshIndicator(
        onRefresh: () async => controller.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600; // Use usual 600 breakpoint
              if (isMobile) {
                return _buildMobileLayout(context);
              }
              return _buildDesktopLayout(context);
            },
          ),
        ),
      ),
    );
  }

  void _navigateTo(AppModule module, String route, {dynamic arguments}) {
    if (PermissionService.to.canAccessModule(module)) {
      Get.toNamed(route, arguments: arguments);
    } else {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép truy cập module này',
        backgroundColor: Colors.orange.shade100,
      );
    }
  }

  // ══════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.dashboard_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569), // Darker gray
                    ),
                  )
                ],
              ),
            ),
            // Body
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  _buildDesktopCards(),
                  const SizedBox(height: 10),
                  _buildDesktopCageBar(),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDesktopRecentActivity()),
                      const SizedBox(width: 10),
                      SizedBox(width: 320, child: _buildDesktopRightSidebar()),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCards() {
    return Row(
      children: [
        Expanded(
          child: _buildGradientCard(
            title: 'Ca khám hôm nay',
            valueRx: controller.todayCases,
            subtitleRx: RxString(''), // Can add dynamic logic later if needed
            colors: [const Color(0xFF7c3aed), const Color(0xFFa78bfa)],
            isCurrency: false,
// This was a stat card, leave it pointing to Routes.cases
            onTap: () => _navigateTo(AppModule.cases, Routes.cases),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => _buildGradientCardItem(
            title: 'Đang nội trú',
            value: controller.occupiedCages.value.toString(),
            subtitle: '${controller.totalCages.value - controller.occupiedCages.value} chuồng trống',
            colors: [const Color(0xFF2563eb), const Color(0xFF60a5fa)],
            onTap: () => _navigateTo(AppModule.hospitalization, Routes.hospitalization),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => _buildGradientCardItem(
            title: 'Doanh thu hôm nay',
            value: Formatters.formatCurrencyShort(controller.todayRevenue.value),
            subtitle: 'Thu từ ${controller.todayCases.value} ca khám',
            colors: [const Color(0xFF0891b2), const Color(0xFF22d3ee)],
            onTap: () => _navigateTo(AppModule.reports, Routes.reports),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => _buildGradientCardItem(
            title: 'Lịch hẹn chờ',
            value: controller.pendingAppointments.value.toString(),
            subtitle: 'Kế tiếp: ${controller.upcomingAppointments.isNotEmpty ? (controller.upcomingAppointments.first['time'] ?? 'N/A') : '--:--'}',
            colors: [const Color(0xFFd97706), const Color(0xFFfbbf24)],
            onTap: () => _navigateTo(AppModule.appointments, Routes.appointments),
          )),
        ),
      ],
    );
  }

  Widget _buildGradientCard({
    required String title,
    required RxInt valueRx,
    required RxString subtitleRx,
    required List<Color> colors,
    bool isCurrency = false,
    VoidCallback? onTap,
  }) {
    return Obx(() => _buildGradientCardItem(
      title: title, 
      value: valueRx.value.toString(), 
      subtitle: subtitleRx.value, 
      colors: colors,
      onTap: onTap,
    ));
  }

  Widget _buildGradientCardItem({
    required String title,
    required String value,
    required String subtitle,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
          children: [
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCageBar() {
    return GestureDetector(
      onTap: () => _navigateTo(AppModule.hospitalization, Routes.hospitalization),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
        children: [
          Row(
            children: [
              const Icon(Icons.pets, size: 16, color: Color(0xFF2563eb)),
              const SizedBox(width: 5),
              const Text(
                'Lưu Chuồng',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              )
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              int total = controller.totalCages.value;
              int occupied = controller.occupiedCages.value;
              int free = total > occupied ? total - occupied : 0;
              // Mocking maintenance for now
              int maintenance = 0;

              return Row(
                children: [
                  _buildCageStatusChip(
                    label: '$occupied đang nội trú',
                    dotColor: const Color(0xFF2563eb),
                    bgColor: const Color(0xFFdbeafe),
                    textColor: const Color(0xFF2563eb),
                  ),
                  const SizedBox(width: 6),
                  _buildCageStatusChip(
                    label: '$free trống',
                    dotColor: const Color(0xFF16a34a),
                    bgColor: const Color(0xFFdcfce7),
                    textColor: const Color(0xFF16a34a),
                  ),
                  const SizedBox(width: 6),
                  _buildCageStatusChip(
                    label: '$maintenance bảo trì',
                    dotColor: const Color(0xFF94a3b8),
                    bgColor: const Color(0xFFf1f5f9),
                    textColor: const Color(0xFF64748b),
                  ),
                ],
              );
            }),
          ),
          Obx(() {
            return Row(
              children: controller.cageOverview.take(10).map((cage) {
                final petCount = cage['pet_count'] as int? ?? 0;
                final isMaintenance = cage['status'] == 'maintenance';
                final name = cage['name']?.toString() ?? '';
                
                Color bgColor;
                Color borderColor;
                Color textColor;

                if (isMaintenance) {
                   bgColor = const Color(0xFFf1f5f9);
                   borderColor = const Color(0xFFcbd5e1);
                   textColor = const Color(0xFF94a3b8);
                } else if (petCount > 0) {
                   bgColor = const Color(0xFF2563eb);
                   borderColor = const Color(0xFF2563eb);
                   textColor = Colors.white;
                } else {
                   bgColor = const Color(0xFFdcfce7);
                   borderColor = const Color(0xFFbbf7d0);
                   textColor = const Color(0xFF16a34a);
                }

                String shortName = name.replaceAll('Chuồng', '').trim();
                if(shortName.isEmpty) shortName = name;
                if(shortName.length > 2) shortName = shortName.substring(0, 2);

                return Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shortName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                );
              }).toList(),
            );
          })
        ],
      ),
    ));
  }

  Widget _buildCageStatusChip({
    required String label,
    required Color dotColor,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11, // Increased font size for cage summary text
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, size: 14, color: Color(0xFF2563eb)),
                const SizedBox(width: 5),
                const Text(
                  'Hoạt Động Gần Đây',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Obx(() {
              if (controller.isLoading.value && controller.recentActivities.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (controller.recentActivities.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('Chưa có hoạt động nào', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ));
              }
              return Column(
                children: controller.recentActivities.map((e) {
                  bool isLast = controller.recentActivities.last == e;
                  
                  IconData icon;
                  Color iconColor;
                  Color iconBg;
                  
                  switch (e['activity_type']) {
                    case 'product_sale':
                      icon = Icons.shopping_cart_rounded;
                      iconColor = const Color(0xFF10b981);
                      iconBg = const Color(0xFFd1fae5);
                      break;
                    case 'hospitalization':
                      icon = Icons.local_hospital_rounded;
                      iconColor = const Color(0xFFf59e0b);
                      iconBg = const Color(0xFFfef3c7);
                      break;
                    case 'hospitalization_discharge':
                      icon = Icons.exit_to_app_rounded;
                      iconColor = const Color(0xFF8b5cf6);
                      iconBg = const Color(0xFFede9fe);
                      break;
                    case 'care_log':
                      icon = Icons.check_circle_outline_rounded;
                      iconColor = const Color(0xFF06b6d4);
                      iconBg = const Color(0xFFcffafe);
                      break;
                    case 'medical_case':
                    default:
                      icon = Icons.medical_services_rounded;
                      iconColor = const Color(0xFF2563eb);
                      iconBg = const Color(0xFFeff6ff);
                  }

                  return _buildActivityFeedRow(
                    icon: icon,
                    iconColor: iconColor,
                    iconBg: iconBg,
                    titleText: e['title'] ?? 'Hoạt động',
                    boldText: '',
                    subtitle: e['customer_name']?.isNotEmpty == true ? 'Khách: ${e['customer_name']}' : (e['reference_code'] ?? ''),
                    timeText: Formatters.formatDateTime(DateTime.tryParse(e['activity_date'] ?? '') ?? DateTime.now()),
                    showBorder: !isLast,
                    onTap: () {
                       final refId = e['ref_id'];
                       final type = e['activity_type'];
                       if (refId == null) return;
                       
                       if (type == 'medical_case') {
                         _navigateTo(AppModule.cases, Routes.cases);
                       } else if (type == 'product_sale') {
                         _navigateTo(AppModule.pharmacy, Routes.pharmacy);
                       } else if (type == 'hospitalization' || type == 'care_log' || type == 'hospitalization_discharge') {
                         _navigateTo(AppModule.hospitalization, Routes.hospitalization);
                       }
                    },
                  );
                }).toList(),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildActivityFeedRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String titleText,
    required String boldText,
    required String subtitle,
    required String timeText,
    bool showBorder = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: Color(0xFFf1f5f9))) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: titleText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Inter',
                    ),
                    children: [
                      TextSpan(
                        text: boldText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ]
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748b), // Darker gray
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748b), // Darker gray
            ),
          )
        ],
      ),
    ),
  );
}

  Widget _buildDesktopRightSidebar() {
    return Column(
      children: [
        _buildDesktopAppointments(),
        const SizedBox(height: 10),
        _buildDesktopReminders(),
        const SizedBox(height: 10),
        _buildDesktopAlerts(),
      ],
    );
  }

  Widget _buildDesktopAppointments() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 14, color: Color(0xFFf59e0b)),
                const SizedBox(width: 5),
                const Text(
                  'Lịch Hẹn Sắp Tới',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B), // Darker color
                  ),
                ),
                const Spacer(),
                Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfef3c7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    controller.upcomingAppointments.length.toString(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFd97706)),
                  ),
                ))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Obx(() {
               if (controller.upcomingAppointments.isEmpty) {
                 return const Center(child: Padding(
                   padding: EdgeInsets.all(10.0),
                   child: Text('Không có lịch hẹn', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                 ));
               }
               return Column(
                 children: controller.upcomingAppointments.map((apt) {
                    bool isLast = controller.upcomingAppointments.last == apt;
                    final dateStr = apt['appointment_date'] as String;
                    final date = DateTime.parse(dateStr).toLocal();
                    String timeStr = apt['time'] ?? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    String dateDisplay = DateFormat('dd/MM/yyyy').format(date);
                    
                    Color barColor = controller.upcomingAppointments.indexOf(apt) % 2 == 0 
                      ? const Color(0xFF2563eb) 
                      : const Color(0xFFf59e0b);

                    return _buildAppointmentItemRow(
                      lineColor: barColor,
                      title: 'Khách: ${apt['customer_name'] ?? 'Khách'} (${apt['pet_name'] ?? 'Pet'})',
                      subtitle: 'Lý do: ${apt['reason'] ?? 'Khám'}',
                      time: timeStr,
                      date: dateDisplay,
                      timeColor: barColor,
                      showBorder: !isLast,
                      onTap: () {
                        try {
                          final aptModel = AppointmentModel.fromJson(apt);
                          _navigateTo(AppModule.appointments, Routes.appointments, arguments: {'showDetail': aptModel});
                        } catch (err) {
                          print('Error parsing deep link: $err');
                          _navigateTo(AppModule.appointments, Routes.appointments);
                        }
                      },
                    );
                 }).toList(),
               );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentItemRow({
    required Color lineColor,
    required String title,
    required String subtitle,
    required String time,
    required String date,
    required Color timeColor,
    bool showBorder = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: Color(0xFFf1f5f9))) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                     fontSize: 11,
                     color: Color(0xFF64748b), // Darker gray
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: timeColor,
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          )
        ],
      ),
    ),
  );
}

  Widget _buildDesktopReminders() {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notification_important_rounded, size: 14, color: Color(0xFFf59e0b)),
                  const SizedBox(width: 5),
                  const Text(
                    'Nhắc Nhở Lưu Chuồng',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B), // Darker text
                    ),
                  ),
                  if (controller.needsProtocolSetup.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfef2f2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        controller.needsProtocolSetup.length.toString(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFdc2626)),
                      ),
                    )
                  ]
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: controller.needsProtocolSetup.isEmpty 
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text('Không có ca nào cần nhắc nhở', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ))
                : Column(
                children: controller.needsProtocolSetup.map((a) {
                  return GestureDetector(
                    onTap: () => _navigateTo(AppModule.hospitalization, Routes.hospitalization),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfef2f2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFFef4444)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            '${a['cage_name']} ${a['pet_name']} — Chưa phác đồ',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFdc2626), fontWeight: FontWeight.w500),
                          )),
                          const Text('Quá 12h', style: TextStyle(fontSize: 11, color: Color(0xFFef4444), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      );
    });
  }

  Widget _buildDesktopAlerts() {
    return Obx(() {
      if (controller.lowStockItems.value == 0) return const SizedBox.shrink();

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, size: 14, color: Color(0xFFef4444)),
                  const SizedBox(width: 5),
                  const Text(
                    'Cảnh Báo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B), // Darker color
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                children: [
                  if (controller.lowStockItems.value > 0)
                  GestureDetector(
                    onTap: () => _navigateTo(AppModule.pharmacy, Routes.pharmacy),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfef2f2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_rounded, size: 14, color: Color(0xFFef4444)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            '${controller.lowStockItems.value} SP sắp hết hàng',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFdc2626), fontWeight: FontWeight.w500),
                          )),
                          const Text('Xem →', style: TextStyle(fontSize: 11, color: Color(0xFFef4444))),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ══════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildMobileHeader(context),
          Container(
            color: const Color(0xFFf1f5f9),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildMobileStatsGrid(),
                const SizedBox(height: 10),
                _buildMobileAppointments(),
                const SizedBox(height: 10),
                _buildMobileAlerts(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // App Bar Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFf1f5f9))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(Icons.menu_rounded, size: 22, color: Color(0xFF475569)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1e293b)),
                  ),
                ),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Icon(Icons.notifications_rounded, size: 20, color: Color(0xFF64748b)),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFef4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Text('2', style: TextStyle(fontSize: 6, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 10),
                const Icon(Icons.cloud_done_rounded, size: 20, color: Color(0xFF10b981)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileStatsGrid() {
    return Obx(() {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.1,
        children: [
          _buildMobileStatCard(
            title: 'Ca khám',
            value: controller.todayCases.value.toString(),
            colors: [const Color(0xFF7c3aed), const Color(0xFFa78bfa)],
            onTap: () => _navigateTo(AppModule.cases, Routes.cases),
          ),
          _buildMobileStatCard(
            title: 'Nội trú',
            value: controller.occupiedCages.value.toString(),
            colors: [const Color(0xFF2563eb), const Color(0xFF60a5fa)],
            onTap: () => _navigateTo(AppModule.hospitalization, Routes.hospitalization),
          ),
          _buildMobileStatCard(
            title: 'Doanh thu',
            value: Formatters.formatCurrencyShort(controller.todayRevenue.value),
            colors: [const Color(0xFF0891b2), const Color(0xFF22d3ee)],
            onTap: () => _navigateTo(AppModule.reports, Routes.reports),
          ),
          _buildMobileStatCard(
            title: 'Lịch hẹn',
            value: controller.pendingAppointments.value.toString(),
            colors: [const Color(0xFFd97706), const Color(0xFFfbbf24)],
            onTap: () => _navigateTo(AppModule.appointments, Routes.appointments),
          ),
        ],
      );
    });
  }

  Widget _buildMobileStatCard({
    required String title,
    required String value,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
            ],
          )
        ],
      ),
    ));
  }

  Widget _buildMobileAppointments() {
    return Obx(() {
      if (controller.upcomingAppointments.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFe2e8f0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.event_rounded, size: 14, color: Color(0xFFf59e0b)),
                const SizedBox(width: 4),
                const Text(
                  'Lịch hẹn sắp tới',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1e293b), // Darker text
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Column(
              children: controller.upcomingAppointments.map((apt) {
                  final dateStr = apt['appointment_date'] as String;
                  final date = DateTime.parse(dateStr).toLocal();
                  String timeStr = apt['time'] ?? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                  String dateDisplay = DateFormat('dd/MM/yyyy').format(date);

                  Color barColor = controller.upcomingAppointments.indexOf(apt) % 2 == 0 
                      ? const Color(0xFF2563eb) 
                      : const Color(0xFFf59e0b);

                  return GestureDetector(
                    onTap: () {
                      try {
                        final aptModel = AppointmentModel.fromJson(apt);
                        _navigateTo(AppModule.appointments, Routes.appointments, arguments: {'showDetail': aptModel});
                      } catch (err) {
                        print('Error parsing deep link: $err');
                        _navigateTo(AppModule.appointments, Routes.appointments);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf8fafc),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Khách: ${apt['customer_name'] ?? 'Khách'} (${apt['pet_name'] ?? 'Pet'})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Lý do: ${apt['reason'] ?? 'Khám'}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748b)), // Darker text
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: barColor,
                              ),
                            ),
                            Text(
                              dateDisplay,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ));
              }).toList(),
            )
          ],
        ),
      );
    });
  }

  Widget _buildMobileAlerts() {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFe2e8f0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded, size: 14, color: Color(0xFFef4444)),
                const SizedBox(width: 4),
                const Text(
                  'Cảnh báo & Nhắc nhở',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1e293b), // Darker text
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            if (controller.needsProtocolSetup.isEmpty && controller.lowStockItems.value == 0)
               const Center(child: Padding(
                 padding: EdgeInsets.all(8.0),
                 child: Text('Không có cảnh báo mới', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
               )),

            if (controller.needsProtocolSetup.isNotEmpty)
              GestureDetector(
                onTap: () => _navigateTo(AppModule.hospitalization, Routes.hospitalization),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfef2f2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notification_important_rounded, size: 14, color: Color(0xFFef4444)),
                      const SizedBox(width: 6),
                      Text(
                        '${controller.needsProtocolSetup.length} ca lưu chuồng cần phác đồ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFdc2626)),
                      )
                    ],
                  ),
                ),
              ),

            if (controller.lowStockItems.value > 0)
              GestureDetector(
                onTap: () => _navigateTo(AppModule.pharmacy, Routes.pharmacy),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfffbeb),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFFf59e0b)),
                      const SizedBox(width: 6),
                      Text(
                        '${controller.lowStockItems.value} SP sắp hết hàng',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFd97706)),
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
