import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/hospitalization_controller.dart';

/// Feature 14: Discharge Checklist Sheet
/// Shows a pre-discharge safety checklist before confirming discharge.
class DischargeChecklistSheet extends StatelessWidget {
  final String hospitalizationId;
  final String petName;
  final HospitalizationController controller;

  const DischargeChecklistSheet({
    super.key,
    required this.hospitalizationId,
    required this.petName,
    required this.controller,
  });

  static void show(
    BuildContext context, {
    required String hospitalizationId,
    required String petName,
    required HospitalizationController controller,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DischargeChecklistSheet(
        hospitalizationId: hospitalizationId,
        petName: petName,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: controller.getDischargeChecklist(hospitalizationId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final checklist = snapshot.data!;
          final allPassed = checklist.values.every(
            (item) => item['passed'] == true,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.checklist,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kiểm Tra Xuất Viện',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            petName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: allPassed
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: allPassed ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Text(
                        allPassed ? '✅ Sẵn sàng' : '⚠️ Chưa đủ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: allPassed
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Checklist items
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: checklist.entries.map((entry) {
                    final item = entry.value;
                    final passed = item['passed'] == true;
                    return Card(
                      elevation: 0,
                      color: passed
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          passed
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          color: passed ? Colors.green : Colors.orange,
                          size: 28,
                        ),
                        title: Text(
                          item['label'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item['detail'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: allPassed
                            ? () {
                                Navigator.pop(context);
                                controller.discharge(hospitalizationId);
                              }
                            : () => _confirmDischargeWithWarning(context),
                        icon: Icon(
                          allPassed ? Icons.check_circle : Icons.warning,
                        ),
                        label: Text(
                          allPassed
                              ? 'Xác Nhận Xuất Viện'
                              : 'Xuất Viện (bỏ qua)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allPassed
                              ? AppColors.success
                              : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDischargeWithWarning(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Xác nhận'),
          ],
        ),
        content: const Text(
          'Một số mục chưa hoàn thành. Bạn vẫn muốn xuất viện?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Không')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Navigator.pop(context);
              controller.discharge(hospitalizationId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Có, xuất viện'),
          ),
        ],
      ),
    );
  }
}
