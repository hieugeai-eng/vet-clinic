import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../controllers/customer_controller.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/pet_model.dart';
import '../../../core/widgets/pro_widgets.dart';

class PetFormDialog extends GetView<CustomerController> {
  final CustomerModel customer;
  final PetModel? pet;

  const PetFormDialog({super.key, required this.customer, this.pet});

  @override
  Widget build(BuildContext context) {
    if (pet != null) {
      controller.setupFormForPetEdit(pet!);
    } else {
      controller.resetPetForm();
    }

    final isMobile = ResponsiveHelper.isMobile(context);

    Widget content = Form(
      key: controller.petFormKey,
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
                    pet != null ? 'Sửa Thú Cưng' : 'Thêm Thú Cưng',
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
            
            // Layout fields
            _buildLabel('Tên thú cưng *'),
            ProTextField(
              controller: controller.petNameController,
              hintText: 'Nhập tên...',
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
                      _buildLabel('Loài *'),
                      Obx(() => Container(
                        height: 44, // Match ProTextField height approx
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.petSpecies.value.isEmpty ? null : controller.petSpecies.value,
                            hint: const Text('Chọn loài...', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            items: ['Chó', 'Mèo', 'Chim', 'Khác'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) controller.petSpecies.value = val;
                            },
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Giống'),
                      ProTextField(
                        controller: controller.petBreedController,
                        hintText: 'Nhập giống...',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Giới tính'),
                      Obx(() => Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.petGender.value.isEmpty ? null : controller.petGender.value,
                            hint: const Text('Giới tính', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            items: ['Đực', 'Cái', 'Chưa rõ'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value == 'Đực' ? '♂ Đực' : (value == 'Cái' ? '♀ Cái' : value), style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) controller.petGender.value = val;
                            },
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Cân nặng'),
                      ProTextField(
                        controller: controller.petWeightController,
                        hintText: 'kg',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Năm sinh'),
                      ProTextField(
                         controller: controller.petBirthOrAgeController,
                         hintText: 'Năm...',
                         keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            Row(
               children: [
                  Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildLabel('Màu lông'),
                         ProTextField(
                           controller: controller.petColorController,
                           hintText: 'Màu...',
                         ),
                       ],
                     ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildLabel('Triệt sản'),
                         Obx(() => Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<bool>(
                            value: controller.petIsNeutered.value,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            items: const [
                              DropdownMenuItem<bool>(value: false, child: Text('Chưa', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem<bool>(value: true, child: Text('Đã triệt sản', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null) controller.petIsNeutered.value = val;
                            },
                          ),
                        ),
                      )),
                       ],
                     ),
                  ),
               ],
            ),

            const SizedBox(height: 16),
            _buildLabel('Ghi chú đặc biệt'),
            ProTextField(
              controller: controller.petHealthNotesController,
              hintText: 'Dị ứng, bệnh nền...',
              maxLines: 2,
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
                            if (pet != null) {
                               // TODO: Call updatePet(pet.id, customer.id) when implemented
                            } else {
                               // add
                               await controller.addPetToCustomer(customer.id);
                            }
                            Get.back();
                          },
                    style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 14),
                       elevation: 0,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                 pet != null ? 'Lưu Cập Nhật' : 'Lưu Thú Cưng',
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
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16).copyWith(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: content,
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440, // Match mockup width
        padding: const EdgeInsets.all(24),
        child: content,
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

void showPetFormDialog(BuildContext context, CustomerModel customer, {PetModel? pet}) {
  if (ResponsiveHelper.isMobile(context)) {
    Get.bottomSheet(
      PetFormDialog(customer: customer, pet: pet),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  } else {
    Get.dialog(PetFormDialog(customer: customer, pet: pet));
  }
}
