import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pro_widgets.dart';
import '../../../../data/models/medicine_model.dart';
import '../../controllers/pharmacy_controller.dart';

class PharmacyMobileView extends GetView<PharmacyController> {
  const PharmacyMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStats(),
        const SizedBox(height: 8),
        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showTransactionForm,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text(
                    'Nhập/Xuất',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showMedicineForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Thêm Thuốc',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildTabsAndSearch(),
        const SizedBox(height: 8),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ── Stats: 2x2 Wrap grid ──────────────────────────────────────────────
  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 8) / 2;
          return Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Tổng',
                    controller.medicines.length.toString(),
                    Icons.medication,
                    AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Sắp hết',
                    controller.lowStockMedicines.length.toString(),
                    Icons.warning_amber,
                    Colors.orange,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Sắp HSD',
                    controller.expiringSoonMedicines.length.toString(),
                    Icons.schedule,
                    Colors.deepOrange,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Hết HSD',
                    controller.expiredMedicines.length.toString(),
                    Icons.dangerous,
                    Colors.red,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabs + Search (stacked) ───────────────────────────────────────────
  Widget _buildTabsAndSearch() {
    return ProInfoCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Tabs
          Obx(
            () => Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _buildTabItem(0, 'Danh Sách')),
                  Expanded(child: _buildTabItem(1, 'Lịch Sử')),
                  Expanded(child: _buildTabItem(2, 'Cảnh Báo')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Search
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: controller.setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'Tìm thuốc...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.loadMedicines,
                  icon: const Icon(Icons.refresh, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = controller.viewTab.value == index;
    return InkWell(
      onTap: () => controller.setViewTab(index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : Colors.grey.shade900,
            ),
          ),
        ),
      ),
    );
  }

  // ── Content switcher ──────────────────────────────────────────────────
  Widget _buildContent() {
    return Obx(() {
      switch (controller.viewTab.value) {
        case 0:
          return _buildMedicineCardList();
        case 1:
          return _buildTransactionList();
        case 2:
          return _buildWarnings();
        default:
          return _buildMedicineCardList();
      }
    });
  }

  // ── Medicine Card List (replaces DataTable) ───────────────────────────
  Widget _buildMedicineCardList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final medicines = controller.filteredMedicines;
      if (medicines.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có thuốc nào',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: medicines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildMedicineCard(medicines[index]),
      );
    });
  }

  Widget _buildMedicineCard(MedicineModel medicine) {
    Color statusColor;
    String statusLabel;
    if (medicine.isExpired) {
      statusColor = Colors.red;
      statusLabel = 'Hết hạn';
    } else if (medicine.isLowStock) {
      statusColor = Colors.orange;
      statusLabel = 'Sắp hết';
    } else if (medicine.isExpiringSoon) {
      statusColor = Colors.orange.shade800;
      statusLabel = 'Sắp hết hạn';
    } else {
      statusColor = Colors.green;
      statusLabel = 'Bình thường';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showMedicineActions(medicine),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: name + status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${medicine.code}${medicine.supplier != null ? ' • ${medicine.supplier}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom row: stock, price, unit, expiry
                Row(
                  children: [
                    _buildInfoChip(
                      'Tồn kho',
                      medicine.stock.toStringAsFixed(0),
                      medicine.isLowStock
                          ? Colors.orange
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      'Giá',
                      controller.formatCurrency(medicine.avgPrice),
                      Colors.grey.shade700,
                    ),
                    if (medicine.unit != null) ...[
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        'ĐV',
                        medicine.unit!,
                        Colors.grey.shade700,
                      ),
                    ],
                    const Spacer(),
                    if (medicine.expiryDate != null)
                      Text(
                        'HSD: ${DateFormat('dd/MM/yy').format(medicine.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: medicine.isExpired
                              ? Colors.red
                              : medicine.isExpiringSoon
                              ? Colors.orange
                              : Colors.grey.shade800,
                          fontWeight:
                              medicine.isExpired || medicine.isExpiringSoon
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade900),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Medicine Actions (BottomSheet) ────────────────────────────────────
  void _showMedicineActions(MedicineModel medicine) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
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
            Text(
              medicine.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(medicine.code, style: TextStyle(color: Colors.grey.shade800)),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: Icons.edit,
              label: 'Sửa thông tin',
              color: Colors.blue,
              onTap: () {
                Get.back();
                _showMedicineForm(medicine: medicine);
              },
            ),
            _buildActionTile(
              icon: Icons.delete,
              label: 'Xóa thuốc',
              color: Colors.red,
              onTap: () {
                Get.back();
                controller.deleteMedicine(medicine);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ── Medicine Form (mobile-optimized) ──────────────────────────────────
  void _showMedicineForm({MedicineModel? medicine}) {
    if (medicine != null) {
      controller.setupFormForEdit(medicine);
    } else {
      controller.resetForm();
    }

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(Get.context!).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: controller.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      medicine != null ? Icons.edit : Icons.add,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      medicine != null ? 'Sửa Thuốc' : 'Thêm Thuốc',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Form fields
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ProTextField(
                        label: 'Mã Thuốc *',
                        controller: controller.codeController,
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'Tên Thuốc *',
                        controller: controller.nameController,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ProTextField(
                              label: 'Đơn Vị',
                              controller: controller.unitController,
                              hint: 'Viên, ml...',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProTextField(
                              label: 'Giá Bán',
                              controller: controller.avgPriceController,
                              keyboardType: TextInputType.number,
                              suffixText: 'VNĐ',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ProTextField(
                              label: 'Tồn Kho',
                              controller: controller.stockController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProTextField(
                              label: 'Tồn Tối Thiểu',
                              controller: controller.minStockController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'Nhà Cung Cấp',
                        controller: controller.supplierController,
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'Số Lô',
                        controller: controller.lotNumberController,
                      ),
                      const SizedBox(height: 12),
                      // Expiry date
                      Obx(
                        () => InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: Get.context!,
                              initialDate:
                                  controller.expiryDate.value ??
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2035),
                            );
                            if (date != null)
                              controller.expiryDate.value = date;
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: Colors.grey.shade900,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  controller.expiryDate.value != null
                                      ? 'HSD: ${DateFormat('dd/MM/yyyy').format(controller.expiryDate.value!)}'
                                      : 'Chọn hạn sử dụng',
                                  style: TextStyle(
                                    color: controller.expiryDate.value != null
                                        ? Colors.black87
                                        : Colors.grey.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                if (controller.expiryDate.value != null)
                                  GestureDetector(
                                    onTap: () =>
                                        controller.expiryDate.value = null,
                                    child: const Icon(Icons.clear, size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Save button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Obx(
                        () => ElevatedButton.icon(
                          onPressed: controller.isLoading.value
                              ? null
                              : () => controller.saveMedicine(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: controller.isLoading.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            medicine != null ? 'Cập Nhật' : 'Lưu',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ── Transaction Form (mobile bottom sheet) ─────────────────────────────
  void _showTransactionForm() {
    controller.resetTransactionForm();
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: controller.transFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Nhập / Xuất Kho',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Transaction type
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTransactionTypeOption(
                          'Nhập Kho',
                          'import',
                          Icons.add_circle,
                        ),
                      ),
                      Expanded(
                        child: _buildTransactionTypeOption(
                          'Xuất Kho',
                          'export',
                          Icons.remove_circle,
                        ),
                      ),
                      Expanded(
                        child: _buildTransactionTypeOption(
                          'Sử Dụng',
                          'use',
                          Icons.medical_services,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Medicine dropdown
                Obx(
                  () => DropdownButtonFormField<String>(
                    value: controller.selectedMedicineId.value.isEmpty
                        ? null
                        : controller.selectedMedicineId.value,
                    decoration: InputDecoration(
                      labelText: 'Chọn Thuốc *',
                      prefixIcon: const Icon(Icons.medication_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items: controller.medicines
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.code} - ${m.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        controller.selectedMedicineId.value = value ?? '',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Chọn thuốc' : null,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Quantity and Price
                Row(
                  children: [
                    Expanded(
                      child: ProTextField(
                        label: 'Số Lượng *',
                        controller: controller.quantityController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.numbers,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProTextField(
                        label: 'Đơn Giá',
                        controller: controller.unitPriceController,
                        keyboardType: TextInputType.number,
                        suffixText: 'VNĐ',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ProTextField(
                  label: 'Mục Đích',
                  controller: controller.purposeController,
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: 12),

                ProTextField(
                  label: 'Ghi Chú',
                  controller: controller.transNotesController,
                  maxLines: 2,
                  prefixIcon: Icons.note_outlined,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Obx(
                        () => ElevatedButton.icon(
                          onPressed: controller.isLoading.value
                              ? null
                              : () async {
                                  await controller.saveTransaction();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getTransactionColor(
                              controller.transactionType.value,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: controller.isLoading.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  controller.transactionType.value == 'import'
                                      ? Icons.add_circle
                                      : Icons.remove_circle,
                                ),
                          label: Text(
                            controller.transactionType.value == 'import'
                                ? 'Nhập Kho'
                                : 'Xuất Kho',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildTransactionTypeOption(
    String label,
    String value,
    IconData icon,
  ) {
    return Obx(() {
      final isSelected = controller.transactionType.value == value;
      final color = _getTransactionColor(value);
      return InkWell(
        onTap: () => controller.transactionType.value = value,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'import':
        return Colors.green;
      case 'export':
        return Colors.orange;
      case 'use':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  // ── Transaction List (reuse card style from desktop) ──────────────────
  Widget _buildTransactionList() {
    return Obx(() {
      if (controller.transactions.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Chưa có lịch sử giao dịch',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(4),
        itemCount: controller.transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final trans = controller.transactions[index];
          final isImport = trans.type == 'import';
          final color = isImport
              ? Colors.green
              : (trans.type == 'use' ? Colors.blue : Colors.orange);
          String typeLabel = trans.type == 'import'
              ? 'Nhập kho'
              : (trans.type == 'use' ? 'Sử dụng' : 'Xuất kho');
          IconData typeIcon = trans.type == 'import'
              ? Icons.add_circle
              : (trans.type == 'use'
                    ? Icons.medical_services
                    : Icons.remove_circle);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.getMedicineName(trans.medicineId),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (trans.purpose != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• ${trans.purpose}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isImport ? '+' : '-'}${trans.quantity.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM HH:mm').format(trans.transactionDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // ── Warnings (same as desktop, already card-based) ────────────────────
  Widget _buildWarnings() {
    return Obx(() {
      final lowStock = controller.lowStockMedicines;
      final expiringSoon = controller.expiringSoonMedicines;
      final expired = controller.expiredMedicines;

      if (lowStock.isEmpty && expiringSoon.isEmpty && expired.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
              const SizedBox(height: 16),
              Text(
                'Không có cảnh báo nào',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade900),
              ),
            ],
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(4),
        children: [
          if (expired.isNotEmpty)
            _buildWarningSection(
              'Thuốc Hết Hạn',
              expired,
              Colors.red,
              Icons.error,
            ),
          if (expiringSoon.isNotEmpty)
            _buildWarningSection(
              'Thuốc Sắp Hết Hạn',
              expiringSoon,
              Colors.orange,
              Icons.event_busy,
            ),
          if (lowStock.isNotEmpty)
            _buildWarningSection(
              'Thuốc Sắp Hết',
              lowStock,
              Colors.yellow.shade800,
              Icons.warning,
            ),
        ],
      );
    });
  }

  Widget _buildWarningSection(
    String title,
    List<MedicineModel> medicines,
    Color color,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$title (${medicines.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ...medicines.map(
            (m) => ListTile(
              dense: true,
              title: Text(m.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                '${m.code} - Tồn: ${m.stock.toStringAsFixed(0)} ${m.unit ?? ''}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: m.expiryDate != null
                  ? Text(
                      DateFormat('dd/MM/yyyy').format(m.expiryDate!),
                      style: TextStyle(color: color, fontSize: 12),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
