import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/hospitalization_models.dart';
import '../../../data/models/medicine_model.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../core/widgets/pro_widgets.dart'; // Assuming ProTextField exists
import '../controllers/regimen_controller.dart';

class RegimenEditorView extends StatefulWidget {
  final RegimenModel? regimen;
  final bool isCustom;
  final Function(RegimenModel)? onSaveCustom;

  const RegimenEditorView({
    super.key,
    this.regimen,
    this.isCustom = false,
    this.onSaveCustom,
  });

  @override
  State<RegimenEditorView> createState() => _RegimenEditorViewState();
}

class _RegimenEditorViewState extends State<RegimenEditorView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _items = <RegimenItem>[].obs;

  final _medicineRepo = MedicineRepository();
  final _availableMedicines = <MedicineModel>[].obs;

  @override
  void initState() {
    super.initState();
    if (widget.regimen != null) {
      _nameController.text = widget.regimen!.name;
      _descController.text = widget.regimen!.description ?? '';
      _items.assignAll(widget.regimen!.items);
    }
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    _availableMedicines.value = await _medicineRepo.getAll();
  }

  void _addItem() {
    final selectedMedicine = Rxn<MedicineModel>();
    final quantity = 1.0.obs;
    final dosage = ''.obs;
    final note = ''.obs;
    final route = ''.obs;
    final frequency = ''.obs;
    final category = ''.obs;
    final duration = ''.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thêm thuốc vào phác đồ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Searchable medicine picker
              Autocomplete<MedicineModel>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _availableMedicines.take(20);
                  }
                  final query = textEditingValue.text.toLowerCase();
                  return _availableMedicines.where(
                    (m) => m.name.toLowerCase().contains(query),
                  );
                },
                displayStringForOption: (m) => m.name,
                onSelected: (m) => selectedMedicine.value = m,
                fieldViewBuilder: (ctx, textCtl, focusNode, onSubmitted) {
                  return TextField(
                    controller: textCtl,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Gõ tên thuốc để tìm...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (_) => selectedMedicine.value = null,
                  );
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 250,
                          maxWidth: 460,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (_, index) {
                            final med = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(
                                med.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${med.unit ?? ""} • Tồn: ${med.stock ?? "?"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.medication,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              onTap: () => onSelected(med),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Row 1: Dosage + Quantity
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Liều lượng',
                        hintText: 'VD: 10mg/kg, 1 viên',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => dosage.value = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'SL',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '1',
                      onChanged: (v) =>
                          quantity.value = double.tryParse(v) ?? 1.0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: Route + Frequency
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Đường dùng',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PO', child: Text('PO (Uống)')),
                        DropdownMenuItem(
                          value: 'IM',
                          child: Text('IM (Tiêm bắp)'),
                        ),
                        DropdownMenuItem(
                          value: 'IV',
                          child: Text('IV (Tĩnh mạch)'),
                        ),
                        DropdownMenuItem(
                          value: 'SC',
                          child: Text('SC (Dưới da)'),
                        ),
                        DropdownMenuItem(
                          value: 'Topical',
                          child: Text('Bôi ngoài'),
                        ),
                        DropdownMenuItem(
                          value: 'Rectal',
                          child: Text('Trực tràng'),
                        ),
                        DropdownMenuItem(
                          value: 'Ophthalmic',
                          child: Text('Nhỏ mắt'),
                        ),
                      ],
                      onChanged: (v) => route.value = v ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Tần suất',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'SID',
                          child: Text('SID (1 lần/ngày)'),
                        ),
                        DropdownMenuItem(
                          value: 'BID',
                          child: Text('BID (2 lần/ngày)'),
                        ),
                        DropdownMenuItem(
                          value: 'TID',
                          child: Text('TID (3 lần/ngày)'),
                        ),
                        DropdownMenuItem(
                          value: 'QID',
                          child: Text('QID (4 lần/ngày)'),
                        ),
                        DropdownMenuItem(
                          value: 'Q4H',
                          child: Text('Q4H (mỗi 4h)'),
                        ),
                        DropdownMenuItem(
                          value: 'Q6H',
                          child: Text('Q6H (mỗi 6h)'),
                        ),
                        DropdownMenuItem(
                          value: 'Q8H',
                          child: Text('Q8H (mỗi 8h)'),
                        ),
                        DropdownMenuItem(
                          value: 'Q12H',
                          child: Text('Q12H (mỗi 12h)'),
                        ),
                        DropdownMenuItem(
                          value: 'PRN',
                          child: Text('PRN (khi cần)'),
                        ),
                        DropdownMenuItem(
                          value: 'CONT',
                          child: Text('Liên tục'),
                        ),
                      ],
                      onChanged: (v) => frequency.value = v ?? '',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 3: Category + Duration
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Nhóm thuốc',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'antibiotic',
                          child: Text('Kháng sinh'),
                        ),
                        DropdownMenuItem(
                          value: 'antiemetic',
                          child: Text('Chống nôn'),
                        ),
                        DropdownMenuItem(
                          value: 'fluid',
                          child: Text('Truyền dịch'),
                        ),
                        DropdownMenuItem(
                          value: 'vitamin',
                          child: Text('Vitamin'),
                        ),
                        DropdownMenuItem(
                          value: 'gastroprotectant',
                          child: Text('Bảo vệ tiêu hóa'),
                        ),
                        DropdownMenuItem(
                          value: 'analgesic',
                          child: Text('Giảm đau'),
                        ),
                        DropdownMenuItem(
                          value: 'antiparasitic',
                          child: Text('Ký sinh trùng'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Khác')),
                      ],
                      onChanged: (v) => category.value = v ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Thời gian điều trị',
                        hintText: 'VD: 5 ngày',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => duration.value = v,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  hintText: 'VD: Uống sau ăn, theo dõi phản ứng...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => note.value = v,
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (selectedMedicine.value != null) {
                        _items.add(
                          RegimenItem(
                            type: 'medicine',
                            refId: selectedMedicine.value!.id,
                            name: selectedMedicine.value!.name,
                            quantity: quantity.value,
                            dosage: dosage.value,
                            unit: selectedMedicine.value!.unit,
                            route: route.value.isNotEmpty ? route.value : null,
                            frequency: frequency.value.isNotEmpty
                                ? frequency.value
                                : null,
                            category: category.value.isNotEmpty
                                ? category.value
                                : null,
                            duration: duration.value.isNotEmpty
                                ? duration.value
                                : null,
                            sortOrder: _items.length, // auto-increment order
                            note: note.value,
                          ),
                        );
                        Get.back();
                      } else {
                        Get.snackbar('Lỗi', 'Vui lòng chọn thuốc từ danh sách');
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm vào phác đồ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCustom
              ? 'Tạo Phác Đồ Cá Nhân'
              : (widget.regimen != null ? 'Sửa Phác Đồ' : 'Tạo Phác Đồ Mới'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Lưu phác đồ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (!widget.isCustom)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên phác đồ',
                        hintText: 'VD: Phác đồ điều trị Parvo',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        hintText: 'Ghi chú về chỉ định, đối tượng...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            if (widget.isCustom)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phác đồ cá nhân không được lưu làm mẫu, chỉ áp dụng cho bệnh nhân hiện tại.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Danh sách thuốc / dịch vụ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm mục'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_items.isEmpty) {
                  return const Center(
                    child: Text('Chưa có thuốc nào trong phác đồ này'),
                  );
                }
                return ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    // Category color mapping
                    Color catColor = Colors.blue;
                    IconData catIcon = Icons.medication;
                    switch (item.category) {
                      case 'antibiotic':
                        catColor = Colors.orange;
                        catIcon = Icons.bug_report;
                        break;
                      case 'antiemetic':
                        catColor = Colors.purple;
                        catIcon = Icons.sick;
                        break;
                      case 'fluid':
                        catColor = Colors.cyan;
                        catIcon = Icons.water_drop;
                        break;
                      case 'vitamin':
                        catColor = Colors.green;
                        catIcon = Icons.eco;
                        break;
                      case 'gastroprotectant':
                        catColor = Colors.amber;
                        catIcon = Icons.shield;
                        break;
                      case 'analgesic':
                        catColor = Colors.red;
                        catIcon = Icons.healing;
                        break;
                      case 'antiparasitic':
                        catColor = Colors.teal;
                        catIcon = Icons.pest_control;
                        break;
                    }
                    final parts = <String>[];
                    if (item.dosage != null && item.dosage!.isNotEmpty)
                      parts.add(item.dosage!);
                    parts.add('SL: ${item.quantity} ${item.unit ?? ''}');
                    if (item.route != null) parts.add(item.route!);
                    if (item.frequency != null) parts.add(item.frequency!);
                    if (item.duration != null) parts.add(item.duration!);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: catColor.withOpacity(0.15),
                        child: Icon(catIcon, color: catColor, size: 20),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (item.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _categoryLabel(item.category!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: catColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parts.join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (item.note != null && item.note!.isNotEmpty)
                            Text(
                              '📝 ${item.note}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade800,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _items.removeAt(index),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'antibiotic':
        return 'Kháng sinh';
      case 'antiemetic':
        return 'Chống nôn';
      case 'fluid':
        return 'Truyền dịch';
      case 'vitamin':
        return 'Vitamin';
      case 'gastroprotectant':
        return 'Bảo vệ TH';
      case 'analgesic':
        return 'Giảm đau';
      case 'antiparasitic':
        return 'KST';
      default:
        return 'Khác';
    }
  }

  void _save() {
    if (widget.isCustom || _formKey.currentState!.validate()) {
      if (_items.isEmpty) {
        Get.snackbar('Lỗi', 'Phác đồ cần ít nhất 1 loại thuốc/dịch vụ');
        return;
      }

      final newRegimen = RegimenModel(
        id: widget.regimen?.id ?? const Uuid().v4(),
        name: widget.isCustom ? 'Phác đồ cá nhân' : _nameController.text,
        description: widget.isCustom
            ? 'Tùy chỉnh riêng cho bệnh nhân'
            : _descController.text,
        items: _items.toList(),
        createdAt: widget.regimen?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.isCustom && widget.onSaveCustom != null) {
        widget.onSaveCustom!(newRegimen);
        Get.back();
      } else {
        final controller = Get.find<RegimenController>();
        final isNew = widget.regimen == null;
        controller.saveRegimen(newRegimen, isNew);
      }
    }
  }
}
