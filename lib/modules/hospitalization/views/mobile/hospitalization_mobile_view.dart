import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hospitalization_controller.dart';
import '../../widgets/cage_grid_view.dart';
import '../../widgets/cage_action_sheet.dart';
import '../daily_care_view.dart';
import '../widgets/hospitalization_dialogs.dart';

class HospitalizationMobileView extends GetView<HospitalizationController> {
  const HospitalizationMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          _buildMobileStats(),
          Expanded(
            child: CageGridView(
              cages: controller.cages,
              alerts: controller.cageAlerts,
              reservations: controller.cageReservations,
              useGrid: false,
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
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMobileStats() {
    int total = controller.cages.length;
    int occupied = controller.cages.where((c) => c.occupants.isNotEmpty).length;
    int alerts = controller.cageAlerts.keys.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.grid_view,
              const Color(0xFF0891B2),
              const Color(0xFFCFFAFE),
              total.toString(),
              'CHUỒNG',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildStatItem(
              Icons.pets,
              const Color(0xFF2563EB),
              const Color(0xFFDBEAFE),
              occupied.toString(),
              'CÓ KHÁCH',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildStatItem(
              Icons.warning,
              const Color(0xFFDC2626),
              const Color(0xFFFEF2F2),
              alerts.toString(),
              'CẢNH BÁO',
              textColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color iconColor,
    Color bgColor,
    String value,
    String label, {
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: iconColor, size: 12),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor ?? const Color(0xFF0F172A),
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 7,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
