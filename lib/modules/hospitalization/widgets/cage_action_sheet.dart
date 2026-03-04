import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/cage_model.dart';

class CageActionSheet extends StatelessWidget {
  final CageModel cage;
  final Function() onAdmit;
  final Function(String hospitalizationId) onDischarge;
  final Function(String hospitalizationId, String petName) onDailyCare;
  final Function(String caseId) onAddService;
  final Function() onMaintenance;
  final Function(String cageId) onReserve; // Phase 3
  final Function(String hospitalizationId)? onPrintDischarge; // Phase 4
  final Function(String hospitalizationId)? onChangeStaff;

  const CageActionSheet({
    Key? key,
    required this.cage,
    required this.onAdmit,
    required this.onDischarge,
    required this.onDailyCare,
    required this.onAddService,
    required this.onMaintenance,
    required this.onReserve,
    this.onPrintDischarge,
    this.onChangeStaff,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isOccupied = cage.occupants.isNotEmpty;
    bool isMaintenance = cage.status == 'maintenance';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMaintenance
                      ? Colors.grey.shade100
                      : (isOccupied
                            ? Colors.blue.shade50
                            : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isMaintenance
                      ? Icons.build
                      : (isOccupied ? Icons.pets : Icons.check),
                  color: isMaintenance
                      ? Colors.grey
                      : (isOccupied ? Colors.blue : Colors.green),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cage.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isOccupied
                          ? '${cage.occupants.length} thú đang lưu trú'
                          : (isMaintenance ? 'Đang bảo trì' : 'Đang trống'),
                      style: TextStyle(color: Colors.grey.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions grid (For Occupied)
          if (isOccupied) ...[
            ...cage.occupants.asMap().entries.map((entry) {
              final occupant = entry.value;
              final days =
                  DateTime.now().difference(occupant.admissionDate).inDays + 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cage.occupants.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Text(
                        '${occupant.petName} (Đang nằm ghép)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.5,
                    children: [
                      _buildGridBtn(
                        icon: Icons.edit_note,
                        label: 'Chăm sóc hằng ngày',
                        color: const Color(0xFF0891B2),
                        onTap: () {
                          Get.back();
                          onDailyCare(
                            occupant.hospitalizationId,
                            occupant.petName,
                          );
                        },
                      ),
                      _buildGridBtn(
                        icon: Icons.assignment_turned_in,
                        label: 'Phiếu điều trị',
                        color: const Color(0xFF16A34A),
                        onTap: () {
                          // TODO: Navigate to treatment sheet
                        },
                      ),
                      _buildGridBtn(
                        icon: Icons.print,
                        label: 'In phiếu xuất viện',
                        color: const Color(0xFF2563EB),
                        onTap: () {
                          Get.back();
                          if (onPrintDischarge != null)
                            onPrintDischarge!(occupant.hospitalizationId);
                        },
                      ),
                      _buildGridBtn(
                        icon: Icons.assignment_ind,
                        label: 'Giao ca / Đổi NV',
                        color: const Color(0xFF0F766E), // teal-700
                        onTap: () {
                          Get.back();
                          if (onChangeStaff != null)
                            onChangeStaff!(occupant.hospitalizationId);
                        },
                      ),
                      _buildGridBtn(
                        icon: Icons.logout,
                        label: 'Xuất viện',
                        color: const Color(0xFFDC2626),
                        borderColor: const Color(0xFFFECACA),
                        onTap: () {
                          Get.back();
                          onDischarge(occupant.hospitalizationId);
                        },
                      ),
                    ],
                  ),
                ],
              );
            }),
          ] else if (isMaintenance) ...[
            SizedBox(
              width: double.infinity,
              child: _buildGridBtn(
                icon: Icons.check_circle_outline,
                label: 'Hoàn tất bảo trì (Mở bán)',
                color: const Color(0xFF16A34A),
                onTap: () {
                  Get.back();
                  onMaintenance();
                },
              ),
            ),
          ] else ...[
            // Empty cage
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  _buildGridBtn(
                    icon: Icons.add_circle,
                    label: 'Nhập viện vào chuồng này',
                    color: const Color(0xFF0891B2),
                    onTap: () {
                      Get.back();
                      onAdmit();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildGridBtn(
                    icon: Icons.event,
                    label: 'Đặt trước chuồng',
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Get.back();
                      onReserve(cage.id);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildGridBtn(
                    icon: Icons.build,
                    label: 'Đánh dấu bảo trì',
                    color: const Color(0xFF64748B),
                    onTap: () {
                      Get.back();
                      onMaintenance();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
