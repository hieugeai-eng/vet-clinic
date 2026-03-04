import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/staff_sync_helper.dart';
import '../controllers/daily_care_controller.dart';
import '../controllers/regimen_controller.dart';
import 'regimen_editor_view.dart';

class RegimenSelectorSheet extends StatefulWidget {
  final DailyCareController controller;

  const RegimenSelectorSheet({super.key, required this.controller});

  @override
  State<RegimenSelectorSheet> createState() => _RegimenSelectorSheetState();
}

class _RegimenSelectorSheetState extends State<RegimenSelectorSheet> {
  String? _selectedStaffId;
  String? _selectedStaffName;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final rows = await StaffSyncHelper.loadStaffWithSync();
      if (mounted) setState(() => _staffList = rows);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final regimenController = Get.put(RegimenController());

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thêm phác đồ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () {
              Get.back(); // close sheet
              Get.to(
                () => RegimenEditorView(
                  isCustom: true,
                  onSaveCustom: (customRegimen) {
                    widget.controller.applyRegimen(
                      customRegimen,
                      assigneeId: _selectedStaffId,
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.edit_document),
            label: const Text('Tạo phác đồ Tùy Chỉnh riêng cho BN này'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Hoặc chọn từ Phác Đồ Mẫu',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),

          // Staff selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedStaffId,
                      hint: const Text('Giao cho nhân viên (tùy chọn)'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '-- Không chỉ định --',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ..._staffList.map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] as String? ?? 'N/A'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedStaffId = v;
                        _selectedStaffName =
                            _staffList.firstWhereOrNull(
                                  (s) => s['id'] == v,
                                )?['name']
                                as String?;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedStaffName != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '👤 Phác đồ sẽ được giao cho: $_selectedStaffName',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 12),
          Expanded(
            child: Obx(() {
              if (regimenController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (regimenController.regimens.isEmpty) {
                return const Center(child: Text('Chưa có phác đồ mẫu nào'));
              }
              return ListView.separated(
                itemCount: regimenController.regimens.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final regimen = regimenController.regimens[index];
                  return ListTile(
                    title: Text(
                      regimen.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${regimen.items.length} thuốc/dịch vụ'),
                    trailing: ElevatedButton(
                      onPressed: () => widget.controller.applyRegimen(
                        regimen,
                        assigneeId: _selectedStaffId,
                      ),
                      child: const Text('Áp dụng'),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
