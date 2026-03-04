import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_colors.dart';
import '../../controllers/hospitalization_controller.dart';
import '../../widgets/cage_grid_view.dart';
import '../../widgets/cage_action_sheet.dart';
import '../cage_config_view.dart';
import '../daily_care_view.dart';
import '../regimen_list_view.dart';
import '../widgets/hospitalization_dialogs.dart';

class HospitalizationDesktopView extends GetView<HospitalizationController> {
  const HospitalizationDesktopView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2), // cyan-600
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_box, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Nội Trú',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => Get.to(() => const CageConfigView()),
                icon: const Icon(
                  Icons.settings,
                  size: 16,
                  color: Color(0xFF475569),
                ),
                label: const Text(
                  'Cấu hình chuồng',
                  style: TextStyle(color: Color(0xFF475569)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => Get.to(() => const RegimenListView()),
                icon: const Icon(
                  Icons.list_alt,
                  size: 16,
                  color: Color(0xFF475569),
                ),
                label: const Text(
                  'Phác đồ',
                  style: TextStyle(color: Color(0xFF475569)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => controller.loadCages(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Get.snackbar(
                    'Thông báo',
                    'Vui lòng chọn một chuồng trống bên dưới để nhập viện.',
                    backgroundColor: Colors.cyan.shade100,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0891B2), // cyan-600
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nhập viện'),
              ),
            ],
          ),
        ),

        // Stats Row
        Obx(() {
          int total = controller.cages.length;
          int empty = controller.cages
              .where((c) => c.status != 'maintenance' && c.occupants.isEmpty)
              .length;
          int occupied = controller.cages
              .where((c) => c.status != 'maintenance' && c.occupants.isNotEmpty)
              .length;
          int maintenance = controller.cages
              .where((c) => c.status == 'maintenance')
              .length;
          int alerts = controller.cageAlerts.keys.length;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    Icons.grid_view,
                    const Color(0xFF0891B2),
                    const Color(0xFFCFFAFE),
                    total.toString(),
                    'TỔNG CHUỒNG',
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  child: _buildStatBox(
                    Icons.check_circle,
                    const Color(0xFF16A34A),
                    const Color(0xFFDCFCE7),
                    empty.toString(),
                    'TRỐNG',
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  child: _buildStatBox(
                    Icons.pets,
                    const Color(0xFF2563EB),
                    const Color(0xFFDBEAFE),
                    occupied.toString(),
                    'CÓ KHÁCH',
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  child: _buildStatBox(
                    Icons.build,
                    const Color(0xFF64748B),
                    const Color(0xFFF1F5F9),
                    maintenance.toString(),
                    'BẢO TRÌ',
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  child: _buildStatBox(
                    Icons.warning,
                    const Color(0xFFDC2626),
                    const Color(0xFFFEE2E2),
                    alerts.toString(),
                    'CẢNH BÁO',
                    textColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          );
        }),

        // Cage Grid Area
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                int cols = 3;
                if (constraints.maxWidth > 1200)
                  cols = 5;
                else if (constraints.maxWidth > 800)
                  cols = 4;

                return CageGridView(
                  cages: controller.cages,
                  alerts: controller.cageAlerts,
                  reservations: controller.cageReservations,
                  useGrid: true,
                  crossAxisCount: cols,
                  onCageTap: (cage) {
                    Get.bottomSheet(
                      CageActionSheet(
                        cage: cage,
                        onAdmit: () => HospitalizationDialogs.showAdmitDialog(
                          context,
                          controller,
                          cage,
                        ),
                        onDischarge: (hospId) {
                          final occupant = cage.occupants.firstWhere(
                            (o) => o.hospitalizationId == hospId,
                            orElse: () => cage.occupants.first,
                          );
                          HospitalizationDialogs.confirmDischarge(
                            context,
                            controller,
                            occupant,
                          );
                        },
                        onDailyCare: (hospId, petName) async {
                          await Get.to(
                            () => DailyCareView(
                              hospitalizationId: hospId,
                              petName: petName,
                            ),
                          );
                          controller.loadCages();
                        },
                        onAddService: (caseId) =>
                            HospitalizationDialogs.showAddMedicineDialog(
                              context,
                              controller,
                              caseId,
                            ),
                        onMaintenance: () => controller.toggleMaintenance(cage),
                        onReserve: (cageId) =>
                            HospitalizationDialogs.showReservationDialog(
                              context,
                              controller,
                              cage,
                            ),
                        onPrintDischarge: (hospId) =>
                            controller.printDischargePaper(hospId),
                        onChangeStaff: (hospId) =>
                            HospitalizationDialogs.showChangeStaffDialog(
                              context,
                              controller,
                              hospId,
                            ),
                      ),
                      isScrollControlled: true,
                      settings: const RouteSettings(
                        arguments: {'maxWidth': 600},
                      ),
                    );
                  },
                );
              },
            );
          }),
        ),

        // Footer Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Obx(() {
            int total = controller.cages.length;
            int occupied = controller.cages
                .where(
                  (c) => c.status != 'maintenance' && c.occupants.isNotEmpty,
                )
                .length;
            int maintenance = controller.cages
                .where((c) => c.status == 'maintenance')
                .length;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hiển thị $total/$total chuồng · $occupied có khách · $maintenance bảo trì',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(
                      'Trống',
                      const Color(0xFF4ADE80),
                    ), // green-500
                    const SizedBox(width: 12),
                    _buildLegendItem(
                      'Có khách',
                      const Color(0xFF3B82F6),
                    ), // blue-500
                    const SizedBox(width: 12),
                    _buildLegendItem(
                      'Cảnh báo',
                      const Color(0xFFF59E0B),
                    ), // amber-500
                    const SizedBox(width: 12),
                    _buildLegendItem(
                      'Bảo trì',
                      const Color(0xFF94A3B8),
                    ), // slate-400
                  ],
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(
    IconData icon,
    Color iconColor,
    Color bgColor,
    String value,
    String label, {
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? const Color(0xFF0F172A),
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 48, color: Colors.grey.shade200);
  }
}
