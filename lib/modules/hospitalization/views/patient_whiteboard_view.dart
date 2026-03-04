import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/hospitalization_controller.dart';
import '../../../data/models/cage_model.dart';
import '../../../core/constants/app_colors.dart';
import 'daily_care_view.dart';

/// Feature 8: Patient Whiteboard — DataTable overview of all active patients
class PatientWhiteboardView extends GetView<HospitalizationController> {
  const PatientWhiteboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      // Collect all occupied cages with occupants
      final occupiedCages = controller.cages
          .where((c) => c.occupants.isNotEmpty)
          .toList();

      if (occupiedCages.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'Không có bệnh nhân đang nhập viện',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        );
      }

      // Flatten: each occupant is a row
      final rows = <_WhiteboardRow>[];
      for (var cage in occupiedCages) {
        for (var occ in cage.occupants) {
          final dayCount =
              DateTime.now().difference(occ.admissionDate).inDays + 1;
          final deposit = controller.deposits[occ.hospitalizationId] ?? 0.0;

          rows.add(
            _WhiteboardRow(
              petName: occ.petName,
              cageName: cage.name,
              dayCount: dayCount,
              hospitalizationId: occ.hospitalizationId,
              caseId: occ.caseId,
              cagePrice: cage.price,
              deposit: deposit,
              alerts: controller.cageAlerts[cage.id] ?? [],
            ),
          );
        }
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Bảng tổng quan bệnh nhân (${rows.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Responsive: Cards on mobile, DataTable on desktop
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return _buildMobileCards(context, rows);
                }
                return _buildDesktopTable(rows);
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMobileCards(BuildContext context, List<_WhiteboardRow> rows) {
    final fmt = NumberFormat('#,###', 'vi');
    return Column(
      children: rows.map((r) {
        final estimated = r.dayCount * r.cagePrice;
        final depositRatio = estimated > 0 ? r.deposit / estimated : 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Pet name + cage + day badge
                Row(
                  children: [
                    const Icon(Icons.pets, size: 18, color: Colors.brown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.petName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.cageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: r.dayCount > 7
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ngày ${r.dayCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: r.dayCount > 7
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: Estimated + Deposit + Status
                Row(
                  children: [
                    // Estimated
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ước tính',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            '${fmt.format(estimated)}đ',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Deposit
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDepositDialog(
                          context,
                          Get.find<HospitalizationController>(),
                          r,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã cọc',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${fmt.format(r.deposit)}đ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: depositRatio < 0.5
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: depositRatio < 0.5
                                      ? Colors.red.shade400
                                      : Colors.green.shade400,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Status
                    if (r.alerts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'OK',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.alerts.join(', '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 3: Action button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Get.to(
                      () => DailyCareView(
                        hospitalizationId: r.hospitalizationId,
                        petName: r.petName,
                      ),
                    ),
                    icon: const Icon(Icons.medical_services, size: 16),
                    label: const Text('Điều trị'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDesktopTable(List<_WhiteboardRow> rows) {
    final fmt = NumberFormat('#,###', 'vi');
    return SizedBox(
      width: double.infinity,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
        columnSpacing: 24,
        columns: const [
          DataColumn(
            label: Text(
              'Bệnh nhân',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Chuồng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold)),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Ước Tính',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Đã Cọc',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Trạng thái',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Hành động',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: rows.map((r) {
          final estimated = r.dayCount * r.cagePrice;
          final depositRatio = estimated > 0 ? r.deposit / estimated : 1.0;
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pets, size: 16, color: Colors.brown),
                    const SizedBox(width: 6),
                    Text(
                      r.petName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(r.cageName, style: const TextStyle(fontSize: 13)),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: r.dayCount > 7
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${r.dayCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: r.dayCount > 7
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  '${fmt.format(estimated)}đ',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              DataCell(
                InkWell(
                  onTap: () => _showDepositDialog(
                    Get.context!,
                    Get.find<HospitalizationController>(),
                    r,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: depositRatio < 0.5
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: depositRatio < 0.5
                            ? Colors.red.shade300
                            : Colors.green.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${fmt.format(r.deposit)}đ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: depositRatio < 0.5
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit,
                          size: 12,
                          color: depositRatio < 0.5
                              ? Colors.red.shade400
                              : Colors.green.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              DataCell(
                r.alerts.isEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Bình thường',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r.alerts.join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              DataCell(
                FilledButton.icon(
                  onPressed: () => Get.to(
                    () => DailyCareView(
                      hospitalizationId: r.hospitalizationId,
                      petName: r.petName,
                    ),
                  ),
                  icon: const Icon(Icons.medical_services, size: 14),
                  label: const Text('Điều trị', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showDepositDialog(
    BuildContext context,
    HospitalizationController controller,
    _WhiteboardRow row,
  ) {
    final textController = TextEditingController(
      text: row.deposit.toStringAsFixed(0),
    );
    final estimated = row.dayCount * row.cagePrice;
    final fmt = NumberFormat('#,###', 'vi');

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cập nhật cọc: ${row.petName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chuồng: ${row.cageName} • Ngày ${row.dayCount}'),
            const SizedBox(height: 8),
            Text(
              'Ước tính: ${fmt.format(estimated)}đ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Số tiền cọc (đ)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(textController.text) ?? 0;
              controller.updateDeposit(
                row.hospitalizationId,
                row.caseId,
                amount,
              );
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }
}

class _WhiteboardRow {
  final String petName;
  final String cageName;
  final int dayCount;
  final String hospitalizationId;
  final String caseId;
  final double cagePrice;
  final double deposit;
  final List<String> alerts;

  _WhiteboardRow({
    required this.petName,
    required this.cageName,
    required this.dayCount,
    required this.hospitalizationId,
    required this.caseId,
    this.cagePrice = 0.0,
    this.deposit = 0.0,
    this.alerts = const [],
  });
}
