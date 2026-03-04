import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:okada_vet_clinic/core/constants/app_colors.dart';
import 'package:okada_vet_clinic/data/models/cage_model.dart';
import 'package:okada_vet_clinic/data/models/medicine_model.dart';
import 'package:okada_vet_clinic/data/providers/local/database_provider.dart';
import 'package:okada_vet_clinic/modules/hospitalization/controllers/hospitalization_controller.dart';
import 'package:okada_vet_clinic/core/services/staff_sync_helper.dart';
import 'package:okada_vet_clinic/core/services/auth_service.dart';

import '../discharge_checklist_sheet.dart';

class HospitalizationDialogs {
  static void showAdmitDialog(
    BuildContext context,
    HospitalizationController controller,
    CageModel cage,
  ) async {
    // Show a loading indicator if needed, but DB query is fast enough.
    final db = await DatabaseProvider.instance.database;
    final activeCases = await db.rawQuery('''
      SELECT mc.id, mc.case_code, mc.pet_id, p.name as pet_name, c.name as customer_name
      FROM medical_cases mc
      JOIN pets p ON mc.pet_id = p.id
      JOIN customers c ON mc.customer_id = c.id
      WHERE mc.status = 'active'
    ''');

    if (activeCases.isEmpty) {
      Get.snackbar(
        'Thông báo',
        'Không có ca bệnh đang điều trị nào để nhập viện.',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    final customPrice = cage.price.obs;

    // Load staff list from LOCAL DB ONLY to prevent UI freeze
    List<Map<String, dynamic>> staffList = [];
    try {
      staffList = (await db.query(
        'staff',
        where: 'is_active = 1',
        orderBy: 'name',
      )).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}

    final selectedStaffId = RxnString();

    // Auto-select current user if available
    if (Get.isRegistered<AuthService>()) {
      final currentId = AuthService.to.currentProfile.value?.id;
      if (currentId != null && staffList.any((s) => s['id'] == currentId)) {
        selectedStaffId.value = currentId;
      }
    }

    // Trigger sync in background without awaiting, so it updates local DB for next time
    StaffSyncHelper.loadStaffWithSync().then((_) {}).catchError((_) {});

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: Get.width > 500 ? 500 : Get.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nhập Viện',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Text(
                    'Giá ngày (VNĐ): ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(
                      () => TextFormField(
                        initialValue: customPrice.value.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                          suffixText: 'đ',
                        ),
                        onChanged: (v) {
                          customPrice.value = double.tryParse(v) ?? 0.0;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Staff Dropdown
              if (staffList.isNotEmpty)
                Obx(
                  () => DropdownButtonFormField<String>(
                    value: selectedStaffId.value,
                    decoration: InputDecoration(
                      labelText: 'Người chăm sóc',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    items: staffList
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] as String? ?? 'Unknown'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => selectedStaffId.value = v,
                    isExpanded: true,
                  ),
                ),
              const SizedBox(height: 16),

              Text(
                'Chọn ca bệnh để nhập vào chuồng ${cage.name}:',
                style: TextStyle(color: Colors.grey.shade900),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: activeCases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = activeCases[index];
                    return InkWell(
                      onTap: () {
                        controller.admitPet(
                          cage,
                          item['id'] as String,
                          item['pet_id'] as String,
                          customPrice.value,
                          staffId: selectedStaffId.value,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pets,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['pet_name']} (#${item['case_code']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Chủ: ${item['customer_name']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showReservationDialog(
    BuildContext context,
    HospitalizationController controller,
    CageModel cage,
  ) async {
    final db = await DatabaseProvider.instance.database;
    final activeCases = await db.rawQuery('''
      SELECT mc.id, mc.case_code, mc.pet_id, p.name as pet_name, c.name as customer_name
      FROM medical_cases mc
      JOIN pets p ON mc.pet_id = p.id
      JOIN customers c ON mc.customer_id = c.id
      ORDER BY mc.created_at DESC
      LIMIT 20
    ''');

    final selectedPetId = RxnString();
    final startDate = DateTime.now().obs;
    final endDate = DateTime.now().add(const Duration(days: 1)).obs;
    final note = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: Get.width > 500 ? 500 : Get.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Đặt Lịch Cho Chuồng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: startDate.value,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2026),
                          );
                          if (d != null) startDate.value = d;
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'Từ: ${DateFormat('dd/MM').format(startDate.value)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: endDate.value,
                            firstDate: startDate.value,
                            lastDate: DateTime(2026),
                          );
                          if (d != null) endDate.value = d;
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'Đến: ${DateFormat('dd/MM').format(endDate.value)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pet Selection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Chọn Pet:"),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  itemCount: activeCases.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = activeCases[index];
                    return Obx(
                      () => RadioListTile<String>(
                        value: item['pet_id'] as String,
                        groupValue: selectedPetId.value,
                        title: Text(item['pet_name'] as String),
                        subtitle: Text(item['customer_name'] as String),
                        onChanged: (v) => selectedPetId.value = v,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    );
                  },
                ),
              ),

              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  if (selectedPetId.value == null) {
                    Get.snackbar('Lỗi', 'Vui lòng chọn Pet');
                    return;
                  }
                  controller.createReservation(
                    cage.id,
                    selectedPetId.value!,
                    startDate.value,
                    endDate.value,
                    note.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Tạo Đặt Lịch',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showAddMedicineDialog(
    BuildContext context,
    HospitalizationController controller,
    String caseId,
  ) {
    final selectedMedicine = Rxn<MedicineModel>();
    final quantity = 1.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: Get.width > 450 ? 450 : Get.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.medication, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Thêm Thuốc / Dịch Vụ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Obx(
                () => DropdownButtonFormField<MedicineModel>(
                  decoration: InputDecoration(
                    labelText: 'Chọn thuốc/dịch vụ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  items: controller.availableMedicines
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            '${m.name} (Tồn: ${m.stock})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => selectedMedicine.value = v,
                  isExpanded: true,
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Text(
                    'Số lượng:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Obx(
                    () => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (quantity.value > 1) quantity.value--;
                            },
                            icon: const Icon(Icons.remove, size: 16),
                          ),
                          Text(
                            '${quantity.value}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => quantity.value++,
                            icon: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedMedicine.value != null) {
                        controller.addServiceToCase(
                          caseId,
                          selectedMedicine.value!,
                          quantity.value,
                        );
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Thêm ngay'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void confirmDischarge(
    BuildContext context,
    HospitalizationController controller,
    CageOccupant occupant,
  ) {
    DischargeChecklistSheet.show(
      context,
      hospitalizationId: occupant.hospitalizationId,
      petName: occupant.petName,
      controller: controller,
    );
  }

  static void showChangeStaffDialog(
    BuildContext context,
    HospitalizationController controller,
    String hospitalizationId,
  ) {
    final selectedStaffId = RxnString(null);

    // Quick load staff
    if (controller.staffList.isEmpty) {
      Get.snackbar('Thông báo', 'Đang tải danh sách nhân sự...');
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Giao ca / Đổi bác sĩ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn bác sĩ/nhân viên phụ trách mới cho ca nội trú này:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Obx(
                  () => DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Chọn nhân viên...'),
                    value: selectedStaffId.value,
                    items: controller.staffList.map((staff) {
                      return DropdownMenuItem<String>(
                        value: staff['id'],
                        child: Text(staff['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      selectedStaffId.value = val;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: selectedStaffId.value != null
                  ? () {
                      controller.changeAssignedStaff(
                        hospitalizationId,
                        selectedStaffId.value!,
                      );
                      Get.back();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E), // teal
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận'),
            ),
          ),
        ],
      ),
    );
  }
}
