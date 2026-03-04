import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/selection_chip.dart';
import '../../../core/widgets/custom_search_field.dart';
import '../../../data/models/customer_model.dart';
import '../controllers/case_form_controller.dart';
import '../widgets/medical_case_layout.dart';

/// Step 1: Reception & Intake (Pro Max Redesign)
class CreateCaseView extends StatefulWidget {
  const CreateCaseView({super.key});

  @override
  State<CreateCaseView> createState() => _CreateCaseViewState();
}

class _CreateCaseViewState extends State<CreateCaseView> {
  late CaseFormController controller;

  @override
  void initState() {
    super.initState();
    // Use permanent: true if we want the data to persist while navigating,
    // or rely on a specific binding. For this flow, we'll put it here if not exists.
    if (!Get.isRegistered<CaseFormController>()) {
      Get.put(CaseFormController(), permanent: true);
    }
    controller = Get.find<CaseFormController>();

    // Always force reinitialize to clear memory of previous PIN sessions
    // because the controller is permanent: true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.forceReinitialize(Get.arguments);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MedicalCaseLayout(
      title: 'Tiếp Nhận Ca Khám',
      currentStep: 0,
      onNext: controller.nextStep,
      onBack: null,
      onCancel: controller.cancelForm,
      child: Obx(
        () => AbsorbPointer(
          absorbing: controller.isCompleted,
          child: _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Reception Info
        AppCard(
          headerTitle: 'Tiếp Nhận',
          headerIcon: FontAwesomeIcons.userNurse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin nhân viên tiếp nhận và khách hàng',
                style: TextStyle(color: AppColors.slate800, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Staff Dropdown
              Obx(() {
                // Build items list, ensuring current staffId is always included
                final staffNames = controller.availableStaff
                    .map((s) => s.name)
                    .toList();
                final currentValue = controller.staffId.value;
                if (currentValue.isNotEmpty &&
                    !staffNames.contains(currentValue)) {
                  staffNames.insert(
                    0,
                    currentValue,
                  ); // Add stored name if not in list
                }
                return DropdownButtonFormField<String>(
                  value: currentValue.isNotEmpty ? currentValue : null,
                  decoration: InputDecoration(
                    labelText: 'Nhân viên / Bác sĩ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: AppColors.slate600,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: staffNames
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (val) => controller.staffId.value = val ?? '',
                );
              }),

              const SizedBox(height: 24),
              const Divider(color: AppColors.border),
              const SizedBox(height: 24),

              // Customer Search & Info
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCustomerSearch()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildCustomerDetails()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildCustomerSearch(),
                        const SizedBox(height: 16),
                        _buildCustomerDetails(),
                      ],
                    ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section 2: Patient Info
        AppCard(
          headerTitle: 'Thông Tin Thú Cưng',
          headerIcon: FontAwesomeIcons.paw,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin chi tiết về thú cưng khám bệnh',
                style: TextStyle(color: AppColors.slate800, fontSize: 13),
              ),
              const SizedBox(height: 16),

              isDesktop
                  ? Row(
                      children: [
                        // Pet Search/Select
                        Expanded(
                          child: Obx(
                            () => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primaryLight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.primary.withAlpha(5),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text(
                                    'Chọn thú cưng có sẵn...',
                                    style: TextStyle(color: AppColors.slate800),
                                  ),
                                  value: controller.selectedPet.value != null
                                      ? controller.selectedPet.value!.id
                                      : '',
                                  icon: const Icon(
                                    Icons.pets,
                                    color: AppColors.primary,
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text(
                                        '-- Thêm Thú Cưng Mới --',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    ...controller.customerPets.map(
                                      (p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(
                                          '${p.name} - ${p.species == 'dog' ? 'Chó' : 'Mèo'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      if (val.isEmpty) {
                                        controller.selectedPet.value = null;
                                      } else {
                                        final pet = controller.customerPets
                                            .firstWhere((pet) => pet.id == val);
                                        controller.selectPet(pet);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryLight),
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.primary.withAlpha(5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text(
                              'Chọn thú cưng có sẵn...',
                              style: TextStyle(color: AppColors.slate800),
                            ),
                            value: controller.selectedPet.value != null
                                ? controller.selectedPet.value!.id
                                : '',
                            icon: const Icon(
                              Icons.pets,
                              color: AppColors.primary,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text(
                                  '-- Thêm Thú Cưng Mới --',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              ...controller.customerPets.map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    '${p.name} - ${p.species == 'dog' ? 'Chó' : 'Mèo'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                if (val.isEmpty) {
                                  controller.selectedPet.value = null;
                                } else {
                                  final pet = controller.customerPets
                                      .firstWhere((pet) => pet.id == val);
                                  controller.selectPet(pet);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 24),
              // Species & Gender
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Loài',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Obx(
                                () => Row(
                                  children: [
                                    Expanded(
                                      child: SelectionChip.primary(
                                        label: 'Chó',
                                        isSelected:
                                            controller.petSpecies.value ==
                                            'dog',
                                        onTap: () {
                                          controller.petSpecies.value = 'dog';
                                          controller.otherSpeciesController
                                              .clear();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectionChip.warning(
                                        label: 'Mèo',
                                        isSelected:
                                            controller.petSpecies.value ==
                                            'cat',
                                        onTap: () {
                                          controller.petSpecies.value = 'cat';
                                          controller.otherSpeciesController
                                              .clear();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectionChip(
                                        label: 'Khác',
                                        isSelected:
                                            controller.petSpecies.value ==
                                            'other',
                                        onTap: () =>
                                            controller.petSpecies.value =
                                                'other',
                                        selectedColor: AppColors.slate900,
                                        selectedBgColor: AppColors.slate100,
                                        selectedBorderColor: AppColors.slate600,
                                      ),
                                    ),
                                    if (controller.petSpecies.value ==
                                        'other') ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: CustomTextField(
                                          controller:
                                              controller.otherSpeciesController,
                                          hint: 'Nhập tên loài...',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Giới tính',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Obx(
                                () => DropdownButtonFormField<String>(
                                  value: controller.petGender.value,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: AppKeys.male,
                                      child: Text('Đực'),
                                    ),
                                    DropdownMenuItem(
                                      value: AppKeys.female,
                                      child: Text('Cái'),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      controller.petGender.value =
                                          val ?? AppKeys.male,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Loài',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => Row(
                                children: [
                                  Expanded(
                                    child: SelectionChip.primary(
                                      label: 'Chó',
                                      isSelected:
                                          controller.petSpecies.value == 'dog',
                                      onTap: () {
                                        controller.petSpecies.value = 'dog';
                                        controller.otherSpeciesController
                                            .clear();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectionChip.warning(
                                      label: 'Mèo',
                                      isSelected:
                                          controller.petSpecies.value == 'cat',
                                      onTap: () {
                                        controller.petSpecies.value = 'cat';
                                        controller.otherSpeciesController
                                            .clear();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectionChip(
                                      label: 'Khác',
                                      isSelected:
                                          controller.petSpecies.value ==
                                          'other',
                                      onTap: () =>
                                          controller.petSpecies.value = 'other',
                                      selectedColor: AppColors.slate900,
                                      selectedBgColor: AppColors.slate100,
                                      selectedBorderColor: AppColors.slate600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Obx(() {
                              if (controller.petSpecies.value == 'other') {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: CustomTextField(
                                    controller:
                                        controller.otherSpeciesController,
                                    hint: 'Nhập tên loài...',
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Giới tính',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: controller.petGender.value,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: AppKeys.male,
                                    child: Text('Đực'),
                                  ),
                                  DropdownMenuItem(
                                    value: AppKeys.female,
                                    child: Text('Cái'),
                                  ),
                                ],
                                onChanged: (val) => controller.petGender.value =
                                    val ?? AppKeys.male,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: AppColors.slate800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

              const SizedBox(height: 16),

              // Pet Details Form
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Tên Thú Cưng',
                            controller: controller.petNameController,
                            hint: 'Nhập tên...',
                            prefixIcon: const Icon(Icons.pets),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: CustomTextField(
                                  label: 'Tuổi',
                                  controller: controller.petAgeController,
                                  hint: 'Nhập số...',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Obx(
                                  () => DropdownButtonFormField<String>(
                                    value: controller.petAgeUnit.value,
                                    decoration: InputDecoration(
                                      labelText: 'Đơn vị',
                                      labelStyle: const TextStyle(
                                        color: AppColors.slate800,
                                        fontSize: 13,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFFAFAFA),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.slate800,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Tháng',
                                        child: Text('Tháng'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Năm',
                                        child: Text('Năm'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null)
                                        controller.petAgeUnit.value = val;
                                    },
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.slate600,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            label: 'Giống (Breed)',
                            controller: controller.petBreedController,
                            hint: 'Poodle...',
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Tên Thú Cưng',
                          controller: controller.petNameController,
                          hint: 'Nhập tên...',
                          prefixIcon: const Icon(Icons.pets),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: CustomTextField(
                                label: 'Tuổi',
                                controller: controller.petAgeController,
                                hint: 'Số...',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Obx(
                                () => DropdownButtonFormField<String>(
                                  value: controller.petAgeUnit.value,
                                  decoration: InputDecoration(
                                    labelText: 'Đơn vị',
                                    labelStyle: const TextStyle(
                                      color: AppColors.slate800,
                                      fontSize: 13,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFFAFAFA),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.slate800,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Tháng',
                                      child: Text('Tháng'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Năm',
                                      child: Text('Năm'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null)
                                      controller.petAgeUnit.value = val;
                                  },
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.slate600,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Giống (Breed)',
                          controller: controller.petBreedController,
                          hint: 'Poodle...',
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSearch() {
    return Column(
      children: [
        CustomTextField(
          label: 'Số điện thoại',
          controller: controller.phoneController,
          hint: 'Tìm hoặc nhập mới...',
          prefixIcon: const Icon(Icons.phone),
          keyboardType: TextInputType.phone,
          suffixText: '🔍',
          onChanged: (val) {
            // Added tap listener behavior
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => controller.searchCustomerByPhone(
              controller.phoneController.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            child: const Text(
              'TÌM KHÁCH HÀNG',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerDetails() {
    return Column(
      children: [
        CustomTextField(
          label: 'Tên Khách Hàng',
          controller: controller.customerNameController,
          hint: 'Nguyễn Văn A',
          prefixIcon: const Icon(Icons.person_outline),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Địa chỉ',
          controller: controller.addressController,
          hint: 'Số nhà, đường...',
          prefixIcon: const Icon(Icons.location_on_outlined),
          maxLines: 2,
        ),
      ],
    );
  }
}
