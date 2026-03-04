import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/medicine_model.dart';
import 'case_attachments_widget.dart';

class ServiceTableRow extends StatefulWidget {
  final CaseServiceModel item;
  final Function(double) onPriceChanged;
  final Function(int) onQuantityChanged;
  final Function(double) onDiscountChanged;
  final Function(String) onNotesChanged;
  final VoidCallback onDelete;
  final VoidCallback onAddMedicine;
  final Function(int, AttachedMedicineModel) onUpdateMedicine;
  final Function(int) onRemoveMedicine;
  final VoidCallback? onReturn;
  final bool readOnly;

  const ServiceTableRow({
    super.key,
    required this.item,
    required this.onPriceChanged,
    required this.onQuantityChanged,
    required this.onDiscountChanged,
    required this.onNotesChanged,
    required this.onDelete,
    required this.onAddMedicine,
    required this.onUpdateMedicine,
    required this.onRemoveMedicine,
    this.onReturn,
    this.readOnly = false,
  });

  @override
  State<ServiceTableRow> createState() => _ServiceTableRowState();
}

class _ServiceTableRowState extends State<ServiceTableRow> {
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _notesController;
  bool _isExpanded = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: Formatters.formatNumber(widget.item.unitPrice),
    );
    _discountController = TextEditingController(
      text: widget.item.discount > 0
          ? Formatters.formatNumber(widget.item.discount)
          : '',
    );
    _notesController = TextEditingController(text: widget.item.notes ?? '');
    if (widget.readOnly) _isExpanded = true; // Auto-expand in read-only mode
  }

  @override
  void didUpdateWidget(ServiceTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.serviceId != oldWidget.item.serviceId) {
      _priceController.text = Formatters.formatNumber(widget.item.unitPrice);
      _discountController.text = widget.item.discount > 0
          ? Formatters.formatNumber(widget.item.discount)
          : '';
      _notesController.text = widget.item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPriceChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
      final newPrice = double.tryParse(cleaned);
      if (newPrice != null) {
        widget.onPriceChanged(newPrice);
      }
    });
  }

  void _onDiscountChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
      final newDiscount = double.tryParse(cleaned) ?? 0;
      widget.onDiscountChanged(newDiscount);
    });
  }

  void _onNotesChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onNotesChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth <
            700; // Switch to card view on smaller screens

        if (isMobile) {
          return _buildMobileCard();
        } else {
          return _buildDesktopRow();
        }
      },
    );
  }

  // --- Desktop Row Layout (Existing) ---
  Widget _buildDesktopRow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                // Expand Icon
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: _isExpanded ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),

                // 1. Name
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.item.serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                // 2. Price
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _priceController,
                      readOnly: widget.readOnly,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _inputDecoration(null),
                      onChanged: widget.readOnly ? null : _onPriceChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Quantity
                Expanded(flex: 2, child: _buildQuantityControl()),
                const SizedBox(width: 8),

                // 4. Discount
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _discountController,
                      readOnly: widget.readOnly,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                      decoration: _inputDecoration('0'),
                      onChanged: widget.readOnly ? null : _onDiscountChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 5. Notes
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _notesController,
                      readOnly: widget.readOnly,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration('...'),
                      onChanged: widget.readOnly ? null : _onNotesChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 6. Total
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.formatCurrency(widget.item.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // 7. Actions (Delete or Return)
                if (!widget.readOnly)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onDelete,
                  )
                else if (widget.onReturn != null)
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_return,
                      color: AppColors.error,
                      size: 18,
                    ),
                    tooltip: 'Hoàn trả hàng / Refund',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onReturn,
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          if (_isExpanded) _buildAttachedMedicines(),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: CaseAttachmentsWidget(
                caseId: widget.item.caseId,
                caseServiceId: widget.item.id,
                serviceName: widget.item.serviceName,
                readOnly: widget.readOnly,
              ),
            ),
        ],
      ),
    );
  }

  // --- Mobile Card Layout (New) ---
  Widget _buildMobileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Name & Delete
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!widget.readOnly)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: widget.onDelete,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                else if (widget.onReturn != null)
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_return,
                      color: AppColors.error,
                    ),
                    tooltip: 'Hoàn trả hàng / Refund',
                    onPressed: widget.onReturn,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body: Inputs Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    // Price
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đơn giá',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _priceController,
                              readOnly: widget.readOnly,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration('0'),
                              onChanged: _onPriceChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Quantity
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SL',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (!widget.readOnly)
                                  InkWell(
                                    onTap: () => widget.onQuantityChanged(
                                      widget.item.quantity - 1,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                Text(
                                  '${widget.item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!widget.readOnly)
                                  InkWell(
                                    onTap: () => widget.onQuantityChanged(
                                      widget.item.quantity + 1,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Total (Highlight)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thành tiền',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.formatCurrency(widget.item.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Discount
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Giảm giá',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _discountController,
                              readOnly: widget.readOnly,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              style: const TextStyle(color: AppColors.error),
                              decoration: _inputDecoration('0'),
                              onChanged: _onDiscountChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Notes (Full width)
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _notesController,
                    readOnly: widget.readOnly,
                    decoration: _inputDecoration('Ghi chú...').copyWith(
                      prefixIcon: const Icon(
                        Icons.edit_note,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    onChanged: widget.readOnly ? null : _onNotesChanged,
                  ),
                ),
              ],
            ),
          ),

          if (_isExpanded) _buildAttachedMedicines(),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: CaseAttachmentsWidget(
                caseId: widget.item.caseId,
                caseServiceId: widget.item.id,
                serviceName: widget.item.serviceName,
                readOnly: widget.readOnly,
              ),
            ),
        ],
      ),
    );
  }

  // --- Shared Components ---

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ), // Slight border for visibility
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade900),
    );
  }

  Widget _buildQuantityControl() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => widget.onQuantityChanged(widget.item.quantity - 1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.remove, size: 14, color: AppColors.primary),
            ),
          ),
          Text(
            '${widget.item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          InkWell(
            onTap: () => widget.onQuantityChanged(widget.item.quantity + 1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.add, size: 14, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedMedicines() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            color: Colors.grey.shade100,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          Row(
            children: [
              const Icon(
                FontAwesomeIcons.pills,
                size: 12,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Thuốc & Vật tư đi kèm (${widget.item.attachedMedicines.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          ...widget.item.attachedMedicines.asMap().entries.map((entry) {
            final index = entry.key;
            final med = entry.value;
            return _AttachedMedicineRow(
              key: ValueKey(
                '${med.medicineId}_$index',
              ), // Unique key for state preservation
              medicine: med,
              readOnly: widget.readOnly,
              onUpdate: (updatedMed) =>
                  widget.onUpdateMedicine(index, updatedMed),
              onRemove: () => widget.onRemoveMedicine(index),
            );
          }).toList(),

          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: widget.onAddMedicine,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Thêm thuốc', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  side: const BorderSide(color: AppColors.primaryLight),
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachedMedicineRow extends StatefulWidget {
  final AttachedMedicineModel medicine;
  final Function(AttachedMedicineModel) onUpdate;
  final VoidCallback onRemove;
  final bool readOnly;

  const _AttachedMedicineRow({
    super.key,
    required this.medicine,
    required this.onUpdate,
    required this.onRemove,
    this.readOnly = false,
  });

  @override
  State<_AttachedMedicineRow> createState() => _AttachedMedicineRowState();
}

class _AttachedMedicineRowState extends State<_AttachedMedicineRow> {
  late TextEditingController _dosageController;
  late TextEditingController _noteController;
  late TextEditingController _qtyController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _dosageController = TextEditingController(text: widget.medicine.dosage);
    _noteController = TextEditingController(text: widget.medicine.note);
    _qtyController = TextEditingController(
      text: widget.medicine.quantity.toString(),
    );
  }

  @override
  void dispose() {
    _dosageController.dispose();
    _noteController.dispose();
    _qtyController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final qty = int.tryParse(_qtyController.text) ?? 1;
      final updated = widget.medicine.copyWith(
        dosage: _dosageController.text,
        note: _noteController.text,
        quantity: qty,
      );
      widget.onUpdate(updated);
    });
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade900),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.medicine.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              if (!widget.readOnly)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.error,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Dosage
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _dosageController,
                    readOnly: widget.readOnly,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDecoration('Liều dùng'),
                    onChanged: widget.readOnly ? null : (_) => _onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Qty
              SizedBox(
                width: 50,
                height: 32,
                child: TextField(
                  controller: _qtyController,
                  readOnly: widget.readOnly,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  decoration: _inputDecoration('SL').copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                  ),
                  onChanged: widget.readOnly ? null : (_) => _onChanged(),
                ),
              ),
              const SizedBox(width: 6),
              // Note
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _noteController,
                    readOnly: widget.readOnly,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDecoration('Ghi chú'),
                    onChanged: widget.readOnly ? null : (_) => _onChanged(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
