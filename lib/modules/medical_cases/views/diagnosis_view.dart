import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/selection_chip.dart';
import '../../../core/widgets/custom_search_field.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/medicine_model.dart';
import '../../../data/models/product_model.dart'; // Added
import '../controllers/case_form_controller.dart';
import '../widgets/medical_case_layout.dart';
import '../widgets/service_table_row.dart';

/// Step 3: Diagnosis & Treatment (Pro Max Redesign)
class DiagnosisView extends StatefulWidget {
  const DiagnosisView({super.key});

  @override
  State<DiagnosisView> createState() => _DiagnosisViewState();
}

class _DiagnosisViewState extends State<DiagnosisView> {
  late CaseFormController controller;
  final TextEditingController _serviceSearchController =
      TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController(); // Added
  final TextEditingController _medicineSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<CaseFormController>()) {
      Get.put(CaseFormController(), permanent: true);
    }
    controller = Get.find<CaseFormController>();
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
    _productSearchController.dispose();
    _medicineSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MedicalCaseLayout(
      title: 'Chẩn Đoán & Điều Trị',
      currentStep: 2,
      onNext: controller.nextStep,
      onBack: controller.previousStep,
      onCancel: controller.cancelForm,
      child: Obx(() {
        final isReadOnly = controller.isCompleted;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Diagnosis & Prognosis (Side-by-side on wide screens)
                AppCard(
                  headerTitle: 'Kết Luận Chẩn Đoán',
                  headerIcon: FontAwesomeIcons.userDoctor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hãy đưa ra chẩn đoán dựa trên kết quả khám',
                        style: TextStyle(
                          color: AppColors.slate800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Top Row: Diagnosis vs Prognosis
                      isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Diagnosis Input (Takes more space)
                                Expanded(
                                  flex: 2,
                                  child: _buildDiagnosisInput(),
                                ),
                                const SizedBox(width: 32),
                                Container(
                                  width: 1,
                                  height: 120,
                                  color: AppColors.border,
                                ), // Divider
                                const SizedBox(width: 32),
                                // Prognosis
                                Expanded(flex: 1, child: _buildPrognosisOnly()),
                              ],
                            )
                          : Column(
                              children: [
                                _buildDiagnosisInput(),
                                const SizedBox(height: 24),
                                const Divider(color: AppColors.border),
                                const SizedBox(height: 24),
                                _buildPrognosisOnly(),
                              ],
                            ),

                      const SizedBox(height: 24),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 24),

                      // Bottom Row: Hospitalization (Full Width)
                      _buildHospitalizationSection(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section 2: Services & Treatment
                AppCard(
                  headerTitle: 'Chỉ Định Dịch Vụ',
                  headerIcon: FontAwesomeIcons.fileInvoiceDollar,
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    children: [
                      // Header & Search
                      if (!isReadOnly)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildServiceSearchField(),
                              const SizedBox(height: 12),
                              _buildProductSearchField(),
                            ],
                          ),
                        ),
                      if (!isReadOnly)
                        const Divider(height: 1, color: AppColors.border),

                      // Services List
                      _buildSelectedServicesList(),

                      const Divider(height: 1, color: AppColors.border),

                      // Final Total
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(12), // 0.05
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tổng Dự Kiến',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate900,
                              ),
                            ),
                            Obx(
                              () => Text(
                                Formatters.formatCurrency(
                                  controller.totalEstimate.value,
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }

  Widget _buildDiagnosisInput() {
    return IgnorePointer(
      ignoring: controller.isCompleted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: 'Kết luận chẩn đoán',
            hint: 'Nhập chẩn đoán bệnh...',
            maxLines: 5, // Taller on text area
            initialValue: controller.diagnosis.value,
            onChanged: (v) => controller.diagnosis.value = v,
          ),
        ],
      ),
    );
  }

  Widget _buildPrognosisOnly() {
    return IgnorePointer(
      ignoring: controller.isCompleted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiên Lượng',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildPrognosisCard(
                  'Tốt',
                  'good',
                  AppColors.success,
                  Icons.thumb_up,
                ),
                _buildPrognosisCard(
                  'Nghi ngờ',
                  'uncertain',
                  AppColors.warning,
                  Icons.help_outline,
                ),
                _buildPrognosisCard(
                  'Xấu',
                  'bad',
                  AppColors.error,
                  Icons.thumb_down,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalizationSection() {
    return IgnorePointer(
      ignoring: controller.isCompleted,
      child: Obx(
        () => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: controller.isHospitalized.value
                ? AppColors.primary.withAlpha(12)
                : AppColors.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: controller.isHospitalized.value
                  ? AppColors.primary.withAlpha(76)
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  'Nhập viện / Lưu chuồng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: controller.isHospitalized.value
                        ? AppColors.primary
                        : AppColors.slate800,
                  ),
                ),
                subtitle: const Text(
                  'Kích hoạt chế độ nội trú và tính phí lưu chuồng',
                  style: TextStyle(color: AppColors.slate800),
                ),
                value: controller.isHospitalized.value,
                activeColor: AppColors.primary,
                inactiveThumbColor: AppColors.slate600,
                onChanged: (v) => controller.isHospitalized.value = v,
                contentPadding: EdgeInsets.zero,
              ),
              if (controller.isHospitalized.value) ...[
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Chọn chuồng',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    prefixIcon: const Icon(
                      Icons.meeting_room,
                      color: AppColors.slate600,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  items: controller.availableCages.map((cage) {
                    final occupantCount = cage.occupants.length;
                    final isMaintenance = cage.status == 'maintenance';
                    String label = '${cage.name} (${cage.type})';
                    if (occupantCount > 0) {
                      label += ' - $occupantCount thú';
                    }
                    if (isMaintenance) {
                      label += ' - Bảo trì';
                    }
                    return DropdownMenuItem(
                      value: cage.id,
                      enabled: !isMaintenance,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isMaintenance ? Colors.grey : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  value:
                      controller.selectedCageId.value.isNotEmpty &&
                          controller.availableCages.any(
                            (c) => c.id == controller.selectedCageId.value,
                          )
                      ? controller.selectedCageId.value
                      : null,
                  onChanged: (val) {
                    controller.selectedCageId.value = val ?? '';
                    if (val != null) {
                      final cage = controller.availableCages.firstWhere(
                        (c) => c.id == val,
                        orElse: () => controller.availableCages.first,
                      );
                      controller.cageNumber.value = cage.name;
                      controller.updateHospitalizationService(val);
                    } else {
                      controller.updateHospitalizationService(null);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrognosisCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final isSelected = controller.prognosis.value == value;
    return SelectionChip(
      label: label,
      icon: icon,
      isSelected: isSelected,
      selectedColor: color,
      selectedBgColor: color.withAlpha(25),
      selectedBorderColor: color,
      onTap: () => controller.prognosis.value = value,
    );
  }

  Widget _buildServiceSearchField() {
    return Obx(() {
      final availableServices = controller.availableServices
          .where(
            (s) => !controller.selectedServices.any(
              (sel) => sel.serviceId == s.id,
            ),
          )
          .toList();

      return CustomSearchField<ServiceModel>(
        controller: _serviceSearchController,
        items: availableServices,
        label: 'Thêm Dịch Vụ',
        hint: 'Gõ để tìm kiếm dịch vụ...',
        prefixIcon: const Icon(
          Icons.add_circle_outline,
          color: AppColors.primary,
        ),
        displayStringForOption: (service) => service.name,
        onSelected: (service) {
          controller.toggleService(service);
          Future.delayed(
            const Duration(milliseconds: 50),
            () => _serviceSearchController.clear(),
          );
        },
        listItemBuilder: (context, service) {
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.healing,
              size: 20,
              color: AppColors.slate800,
            ),
            title: Text(
              service.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              Formatters.formatCurrency(service.basePrice),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildProductSearchField() {
    return Obx(() {
      final products = controller.availableProducts
          .where(
            (p) => !controller.selectedServices.any(
              (sel) => sel.serviceId == p.id,
            ),
          )
          .toList();

      return CustomSearchField<ProductModel>(
        controller: _productSearchController,
        items: products,
        label: 'Thêm Từ Petshop',
        hint: 'Gõ để tìm sản phẩm petshop...',
        prefixIcon: const Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.primary,
        ),
        displayStringForOption: (product) => product.name,
        onSelected: (product) {
          if (product.stock <= 0) {
            Get.snackbar('Hết hàng', '${product.name} đã hết hàng trong kho');
            return;
          }
          controller.toggleProduct(product);
          Future.delayed(
            const Duration(milliseconds: 50),
            () => _productSearchController.clear(),
          );
        },
        listItemBuilder: (context, product) {
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.inventory_2,
              size: 20,
              color: product.stock > 0 ? AppColors.success : AppColors.error,
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Tồn: ${product.stock}',
              style: TextStyle(
                fontSize: 12,
                color: product.stock > 0 ? AppColors.slate900 : AppColors.error,
              ),
            ),
            trailing: Text(
              Formatters.formatCurrency(product.salePrice),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSelectedServicesList() {
    return Obx(() {
      final list = controller.selectedServices;

      if (list.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(40),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade200),
              const SizedBox(height: 16),
              const Text(
                'Chưa có dịch vụ nào',
                style: TextStyle(color: AppColors.slate600),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Header row - only show on desktop (ServiceTableRow switches to card at <700px)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(color: AppColors.slate50),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 36,
                    ), // Space for expand icon (InkWell with padding 8 + icon 20 + padding 8 = 36)
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Dịch vụ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Đơn giá',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          'SL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'C.Khấu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Ghi chú',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Thành tiền',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                    SizedBox(width: 40), // Space for delete button + margin
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          // Services list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: AppColors.border,
            ),
            itemBuilder: (context, index) {
              final item = list[index];
              return _buildServiceTableRow(item);
            },
          ),
        ],
      );
    });
  }

  Widget _buildServiceTableRow(dynamic item) {
    return ServiceTableRow(
      key: ValueKey(item.serviceId),
      item: item,
      readOnly: controller.isCompleted,
      onPriceChanged: (val) =>
          controller.updateServicePrice(item.serviceId, val),
      onQuantityChanged: (val) =>
          controller.updateServiceQuantity(item.serviceId, val),
      onDiscountChanged: (val) =>
          controller.updateServiceDiscount(item.serviceId, val),
      onNotesChanged: (val) =>
          controller.updateServiceNotes(item.serviceId, val),
      onDelete: () => controller.updateServiceQuantity(item.serviceId, 0),
      onAddMedicine: () => _showAddMedicineDialog(item.serviceId),
      onUpdateMedicine: (idx, med) =>
          controller.updateAttachedMedicine(item.serviceId, idx, med),
      onRemoveMedicine: (idx) =>
          controller.removeAttachedMedicine(item.serviceId, idx),
      onReturn:
          controller.isCompleted &&
              item.serviceName.startsWith('Petshop: ') &&
              !(item.notes ?? '').contains('[Đã trả')
          ? () => _showReturnDialog(item)
          : null,
    );
  }

  void _showAddMedicineDialog(String serviceId) {
    Get.dialog(
      AddMedicineDialog(
        availableMedicines: controller.availableMedicines,
        onAdd: (medicine, dosage, note, quantity) {
          controller.addAttachedMedicine(
            serviceId,
            medicine,
            dosage: dosage,
            note: note,
            quantity: quantity,
          );
        },
      ),
    );
  }

  void _showReturnDialog(CaseServiceModel item) {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final amountController = TextEditingController(
      text: Formatters.formatNumber(item.total),
    );

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Hoàn trả sản phẩm',
          style: TextStyle(color: AppColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sản phẩm: ${item.serviceName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Số lượng trả',
              controller: quantityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Số tiền hoàn lại',
              controller: amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Lưu ý: Việc này sẽ cộng lại tồn kho cho sản phẩm và tạo một Phiếu Chi hoàn tiền, nhưng không làm thay đổi doanh thu bệnh án gốc.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slate800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.slate800),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 0;
              final amt =
                  double.tryParse(
                    amountController.text.replaceAll(RegExp(r'[^\d]'), ''),
                  ) ??
                  0;

              if (qty > 0 && qty <= item.quantity) {
                Get.back();
                controller.returnServiceItem(item, qty, amt);
              } else {
                Get.snackbar(
                  'Lỗi',
                  'Số lượng không hợp lệ',
                  backgroundColor: Colors.red.shade100,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận trả'),
          ),
        ],
      ),
    );
  }
}

class AddMedicineDialog extends StatefulWidget {
  final List<MedicineModel> availableMedicines;
  final Function(MedicineModel, String, String, int) onAdd;

  const AddMedicineDialog({
    super.key,
    required this.availableMedicines,
    required this.onAdd,
  });

  @override
  State<AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<AddMedicineDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  MedicineModel? _selectedMedicine;

  @override
  void dispose() {
    _searchController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm thuốc / Vật tư'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: ResponsiveHelper.dialogWidth(context, 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search (Always visible if no medicine selected, or top if selected)
              if (_selectedMedicine == null)
                CustomSearchField<MedicineModel>(
                  controller: _searchController,
                  items: widget.availableMedicines,
                  label: 'Tìm thuốc',
                  hint: 'Nhập tên thuốc...',
                  displayStringForOption: (m) => '${m.name} (Tồn: ${m.stock})',
                  onSelected: (medicine) {
                    if (medicine.stock <= 0) {
                      Get.snackbar('Hết hàng', 'Thuốc đã hết hàng');
                      return;
                    }
                    setState(() {
                      _selectedMedicine = medicine;
                    });
                  },
                  listItemBuilder: (context, medicine) {
                    return ListTile(
                      dense: true,
                      title: Text(medicine.name),
                      subtitle: Text('Tồn: ${medicine.stock}'),
                      trailing: Text(
                        Formatters.formatCurrency(medicine.avgPrice),
                      ),
                    );
                  },
                )
              else ...[
                // Selected Medicine Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMedicine!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            ),
                            Text(
                              'Tồn kho: ${_selectedMedicine!.stock}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.info),
                        onPressed: () => setState(() {
                          _selectedMedicine = null;
                          _searchController.clear();
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Input Fields
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Liều lượng',
                        controller: _dosageController,
                        hint: 'VD: 10mg/kg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: CustomTextField(
                        label: 'Số lượng',
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        hint: '1',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Ghi chú',
                  controller: _noteController,
                  hint: 'Cách dùng, lưu ý...',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Hủy', style: TextStyle(color: AppColors.slate800)),
        ),
        if (_selectedMedicine != null)
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(_quantityController.text) ?? 1;
              widget.onAdd(
                _selectedMedicine!,
                _dosageController.text,
                _noteController.text,
                qty,
              );
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Thêm vào dịch vụ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
