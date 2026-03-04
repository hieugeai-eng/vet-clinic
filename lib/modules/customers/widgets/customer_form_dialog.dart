import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../controllers/customer_controller.dart';
import '../../../data/models/customer_model.dart';
import '../../../core/widgets/pro_widgets.dart';

class CustomerFormDialog extends GetView<CustomerController> {
  final CustomerModel? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer != null) {
      controller.setupFormForEdit(customer!);
    } else {
      controller.resetForm();
    }

    final isMobile = ResponsiveHelper.isMobile(context);

    // If mobile, show as full screen or large bottom sheet, else standard dialog.
    // For now, sticking to standard dialog with responsive width.
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: isMobile ? const EdgeInsets.all(16) : null,
      child: Container(
        width: ResponsiveHelper.dialogWidth(context, 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: controller.formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer != null ? 'Sửa Khách Hàng' : 'Thêm Khách Hàng',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Form fields based on mockup style
                _buildLabel('Họ và tên *'),
                ProTextField(
                  controller: controller.nameController,
                  hintText: 'Nhập họ tên...',
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Vui lòng nhập tên';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Số điện thoại *'),
                          ProTextField(
                            controller: controller.phoneController,
                            hintText: '0912...',
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Bắt buộc';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Email'),
                          ProTextField(
                            // controller: controller.emailController, // Pending implementation in controller
                            hintText: 'email@...',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                _buildLabel('Địa chỉ'),
                ProTextField(
                  controller: controller.addressController,
                  hintText: 'Nhập địa chỉ...',
                ),
                
                const SizedBox(height: 16),
                _buildLabel('Ghi chú'),
                ProTextField(
                  // controller: controller.notesController, // Pending implementation in controller
                  hintText: 'Ghi chú...',
                  maxLines: 3,
                ),
                
                const SizedBox(height: 32),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Obx(() => ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () async {
                                if (await controller.saveCustomer()) {
                                  Get.back();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 14),
                           elevation: 0,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           // Note: Ink ink response doesn't inherit gradient directly via styleFrom 
                           // For perfectly matching mockup, use Ink + Container
                        ),
                        child: Ink(
                           decoration: BoxDecoration(
                               gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                               ),
                               borderRadius: BorderRadius.circular(8)
                           ),
                           child: Container(
                               alignment: Alignment.center,
                               constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
                               child: controller.isLoading.value 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(
                                     customer != null ? 'Lưu Cập Nhật' : 'Lưu Khách Hàng',
                                     style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                  )
                           )
                        )
                      )),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

void showCustomerFormDialog(BuildContext context, {CustomerModel? customer}) {
  Get.dialog(CustomerFormDialog(customer: customer));
}
