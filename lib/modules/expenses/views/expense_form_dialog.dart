import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../../../data/models/expense_model.dart';
import '../controllers/expense_controller.dart';

class ExpenseFormDialog extends StatefulWidget {
  final ExpenseModel? expense;

  const ExpenseFormDialog({super.key, this.expense});

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseController controller = Get.find();

  late TextEditingController _contentController;
  late TextEditingController _amountController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _staffController;
  late TextEditingController _notesController;
  late TextEditingController _dateController;

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = ExpenseCategory.other;
  String _type = 'expense'; // 'income' or 'expense'
  String _paymentMethod = 'cash'; // 'cash' or 'transfer'

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _selectedDate = e?.date ?? DateTime.now();
    _selectedCategory = e?.category ?? ExpenseCategory.other;
    _type = e?.type ?? 'expense';
    _paymentMethod = e?.paymentMethod ?? 'cash';

    // Auto-assign current staff name
    final currentStaffName = Get.isRegistered<PermissionService>()
        ? PermissionService.to.currentStaffName.value ?? ''
        : '';

    _contentController = TextEditingController(text: e?.content ?? '');
    _amountController = TextEditingController(
      text: e?.amount.toStringAsFixed(0) ?? '',
    );
    _quantityController = TextEditingController(
      text: e?.quantity?.toString() ?? '1',
    );
    _unitController = TextEditingController(text: e?.unit ?? '');
    _staffController = TextEditingController(
      text: e?.staffId ?? currentStaffName,
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_selectedDate),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _amountController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _staffController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: ResponsiveHelper.dialogWidth(context, 600),
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height *
              0.9, // Adjust height slightly to allow scrolling inner
        ),
        padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 16 : 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isEditing ? Icons.edit : Icons.add,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        isEditing
                            ? (_type == 'income'
                                  ? 'Sửa khoản thu'
                                  : 'Sửa khoản chi')
                            : 'Thêm giao dịch mới',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Loai Giao Dich (Thu / Chi)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _type = 'income'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'income'
                                ? Colors.green.shade50
                                : Colors.transparent,
                            border: Border.all(
                              color: _type == 'income'
                                  ? Colors.green
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Khoản Thu',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _type == 'income'
                                    ? Colors.green.shade700
                                    : Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _type = 'expense'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'expense'
                                ? Colors.red.shade50
                                : Colors.transparent,
                            border: Border.all(
                              color: _type == 'expense'
                                  ? Colors.red
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Khoản Chi',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _type == 'expense'
                                    ? Colors.red.shade700
                                    : Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Hinh thuc thanh toan (Tien mat / Chuyen khoan)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Hình thức:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Radio<String>(
                      value: 'cash',
                      groupValue: _paymentMethod,
                      onChanged: (v) => setState(() => _paymentMethod = v!),
                    ),
                    const Text('Tiền mặt'),
                    const SizedBox(width: 8),
                    Radio<String>(
                      value: 'transfer',
                      groupValue: _paymentMethod,
                      onChanged: (v) => setState(() => _paymentMethod = v!),
                    ),
                    const Text('Chuyển khoản'),
                  ],
                ),
                const SizedBox(height: 16),
                ProTextField(
                  label: 'Ngày giao dịch',
                  controller: _dateController,
                  prefixIcon: Icons.calendar_today,
                  readOnly: true,
                  onTap: _pickDate,
                  validator: (v) => v!.isEmpty ? 'Chọn ngày' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Hạng mục',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  items: ExpenseCategory.all
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(height: 16),
                ProTextField(
                  label: 'Nội dung',
                  hintText: 'VD: Mua giấy A4, Trả tiền điện, Thu tiền...',
                  controller: _contentController,
                  prefixIcon: Icons.description_outlined,
                  validator: (v) => v!.isEmpty ? 'Nhập nội dung' : null,
                ),
                const SizedBox(height: 16),
                ProTextField(
                  label: 'Số tiền',
                  controller: _amountController,
                  prefixIcon: Icons.attach_money,
                  suffixText: 'VNĐ',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v!.isEmpty ? 'Nhập số tiền' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ProTextField(
                        label: 'SL',
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ProTextField(
                        label: 'Đơn vị',
                        controller: _unitController,
                        hintText: 'cái, kg...',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ProTextField(
                  label: 'Người thực hiện / thụ hưởng',
                  controller: _staffController,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                ProTextField(
                  label: 'Ghi chú',
                  controller: _notesController,
                  prefixIcon: Icons.note_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEditing &&
                        PermissionService.to.can(AppPermission.expensesDelete))
                      TextButton.icon(
                        onPressed: () => _confirmDelete(),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Xóa',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          backgroundColor: Colors.red.shade50,
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isEditing ? 'Cập Nhật' : 'Thêm Mới'),
                        ),
                      ],
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

  void _save() {
    if (_formKey.currentState!.validate()) {
      final expense = ExpenseModel(
        id: widget.expense?.id ?? '',
        date: _selectedDate,
        content: _contentController.text,
        category: _selectedCategory,
        type: _type,
        paymentMethod: _paymentMethod,
        amount: double.tryParse(_amountController.text) ?? 0,
        quantity: int.tryParse(_quantityController.text),
        unit: _unitController.text.isEmpty ? null : _unitController.text,
        staffId: _staffController.text.isEmpty ? null : _staffController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        unitPrice:
            (_quantityController.text.isNotEmpty &&
                _amountController.text.isNotEmpty)
            ? (double.tryParse(_amountController.text) ?? 0) /
                  (int.tryParse(_quantityController.text) ?? 1)
            : null,
      );

      if (widget.expense != null) {
        controller.updateExpense(expense);
      } else {
        controller.addExpense(expense);
      }
      Get.back();
    }
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn xóa giao dịch này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (widget.expense != null) {
                controller.deleteExpense(widget.expense!.id);
              }
              Navigator.of(context).pop(); // close alert dialog
              Navigator.of(context).pop(); // close form dialog
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
