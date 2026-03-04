import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/selection_chip.dart';
import '../controllers/case_form_controller.dart';
import '../widgets/medical_case_layout.dart';

/// Step 2: Clinical Examination (Pro Max Redesign)
class ClinicalExamView extends StatefulWidget {
  const ClinicalExamView({super.key});

  @override
  State<ClinicalExamView> createState() => _ClinicalExamViewState();
}

class _ClinicalExamViewState extends State<ClinicalExamView> {
  late CaseFormController controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<CaseFormController>()) {
      Get.put(CaseFormController(), permanent: true);
    }
    controller = Get.find<CaseFormController>();
  }

  @override
  Widget build(BuildContext context) {
    return MedicalCaseLayout(
      title: 'Khám Lâm Sàng',
      currentStep: 1,
      onNext: controller.nextStep,
      onBack: controller.previousStep,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800; // Define Desktop breakpoint

        final vitalsCard = AppCard(
          headerTitle: 'Sinh Hiệu',
          headerIcon: FontAwesomeIcons.heartPulse,
          headerIconColor: AppColors.info,
          child: Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Cân nặng (kg)',
                  hint: '0.0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  initialValue: controller.weight.value,
                  onChanged: (v) => controller.weight.value = v,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomTextField(
                  label: 'Nhiệt độ (°C)',
                  hint: '0.0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  initialValue: controller.temperature.value,
                  onChanged: (v) => controller.temperature.value = v,
                ),
              ),
            ],
          ),
        );

        final bodyConditionCard = AppCard(
          headerTitle: 'Thể Trạng',
          headerIcon: FontAwesomeIcons.childReaching,
          headerIconColor: AppColors.success,
          child: Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  'Bình thường',
                  AppKeys.bodyNormal,
                  controller.bodyCondition.value,
                  AppColors.success,
                  type: 'body',
                ),
                _buildChip(
                  'Ốm/Gầy',
                  AppKeys.bodyThin,
                  controller.bodyCondition.value,
                  AppColors.warning,
                  type: 'body',
                ),
                _buildChip(
                  'Thừa cân',
                  AppKeys.bodyFat,
                  controller.bodyCondition.value,
                  AppColors.primary,
                  type: 'body',
                ),
                _buildChip(
                  'Béo phì',
                  AppKeys.bodyObese,
                  controller.bodyCondition.value,
                  AppColors.error,
                  type: 'body',
                ),
              ],
            ),
          ),
        );

        final stoolCard = AppCard(
          headerTitle: 'Tiêu Hóa (Phân)',
          headerIcon: FontAwesomeIcons.poop,
          headerIconColor: AppColors.warning,
          child: Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  'Bình thường',
                  AppKeys.stoolNormal,
                  controller.stoolCondition.value,
                  AppColors.success,
                  type: 'stool',
                ),
                _buildChip(
                  'Phân lỏng',
                  AppKeys.stoolLiquid,
                  controller.stoolCondition.value,
                  AppColors.warning,
                  type: 'stool',
                ),
                _buildChip(
                  'Phân cứng',
                  AppKeys.stoolHard,
                  controller.stoolCondition.value,
                  AppColors.primary,
                  type: 'stool',
                ),
                _buildChip(
                  'Phân máu',
                  AppKeys.stoolBlood,
                  controller.stoolCondition.value,
                  AppColors.error,
                  type: 'stool',
                ),
              ],
            ),
          ),
        );

        final mentalCard = AppCard(
          headerTitle: 'Tinh Thần',
          headerIcon: FontAwesomeIcons.brain,
          headerIconColor: AppColors.info,
          child: Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  'Tỉnh táo',
                  AppKeys.mentalAlert,
                  controller.mentalStatus.value,
                  AppColors.success,
                  type: 'mental',
                ),
                _buildChip(
                  'Mệt mỏi',
                  AppKeys.mentalTired,
                  controller.mentalStatus.value,
                  AppColors.warning,
                  type: 'mental',
                ),
                _buildChip(
                  'Lờ đờ',
                  AppKeys.mentalLethargic,
                  controller.mentalStatus.value,
                  AppColors.error,
                  type: 'mental',
                ),
                _buildChip(
                  'Kích động',
                  AppKeys.mentalRestless,
                  controller.mentalStatus.value,
                  AppColors.error,
                  type: 'mental',
                ),
              ],
            ),
          ),
        );

        final skinCard = AppCard(
          headerTitle: 'Da & Niêm Mạc',
          headerIcon: FontAwesomeIcons.eye,
          child: CustomTextField(
            hint: 'Nhập tình trạng da, niêm mạc...',
            initialValue: controller.skinMucosa.value,
            onChanged: (v) => controller.skinMucosa.value = v,
            maxLines: 4,
          ),
        );

        final notesCard = AppCard(
          headerTitle: 'Ghi chú khám lâm sàng (Khác)',
          headerIcon: FontAwesomeIcons.notesMedical,
          child: CustomTextField(
            hint: 'Hô hấp, Vận động...',
            initialValue: controller.otherInfo.value,
            onChanged: (v) => controller.otherInfo.value = v,
            maxLines: 4,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Reasons (Keep Full Width)
            AppCard(
              headerTitle: 'Khám Lâm Sàng',
              headerIcon: FontAwesomeIcons.userDoctor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ghi nhận lý do khám và triệu chứng',
                    style: TextStyle(
                      color: AppColors.slate800,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.visitReasonOptions.map((reason) {
                        final isSelected = controller.visitReasons.contains(
                          reason,
                        );

                        // Translation Map
                        final labelMap = {
                          AppKeys.vomit: 'Nôn mửa',
                          AppKeys.weak: 'Yếu',
                          AppKeys.tired: 'Mệt mỏi',
                          AppKeys.accident: 'Tai nạn',
                          AppKeys.fever: 'Sốt',
                          AppKeys.diarrhea: 'Tiêu chảy',
                          AppKeys.nopet: 'Bỏ ăn',
                          AppKeys.breath: 'Khó thở',
                          AppKeys.itch: 'Ngứa / Viêm da',
                          AppKeys.other: 'Khác',
                        };

                        return SelectionChip.warning(
                          label: labelMap[reason] ?? reason,
                          isSelected: isSelected,
                          onTap: () => controller.toggleVisitReason(reason),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Chi tiết triệu chứng',
                    controller:
                        TextEditingController(
                            text: controller.reasonNotes.value,
                          )
                          ..selection = TextSelection.collapsed(
                            offset: controller.reasonNotes.value.length,
                          ),
                    hint: 'Nhập ghi chú chi tiết triệu chứng...',
                    maxLines: 2,
                    onChanged: (v) => controller.reasonNotes.value = v,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Form Grid Fields
            if (isWide) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: vitalsCard),
                    const SizedBox(width: 16),
                    Expanded(child: bodyConditionCard),
                    const SizedBox(width: 16),
                    Expanded(child: stoolCard),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 1, child: mentalCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: skinCard),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              notesCard,
            ] else ...[
              vitalsCard,
              const SizedBox(height: 16),
              bodyConditionCard,
              const SizedBox(height: 16),
              stoolCard,
              const SizedBox(height: 16),
              mentalCard,
              const SizedBox(height: 16),
              skinCard,
              const SizedBox(height: 16),
              notesCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildChip(
    String label,
    String value,
    String currentValue,
    Color color, {
    String type = 'body',
  }) {
    final isSelected = currentValue == value;
    return SelectionChip(
      label: label,
      isSelected: isSelected,
      selectedColor: color,
      selectedBgColor: color.withAlpha(25),
      selectedBorderColor: color,
      onTap: () {
        switch (type) {
          case 'body':
            controller.bodyCondition.value = value;
            break;
          case 'stool':
            controller.stoolCondition.value = value;
            break;
          case 'mental':
            controller.mentalStatus.value = value;
            break;
        }
      },
    );
  }
}
