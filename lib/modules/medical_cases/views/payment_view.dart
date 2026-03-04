import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/selection_chip.dart';
import '../controllers/case_form_controller.dart';
import '../widgets/medical_case_layout.dart';

/// Step 4: Payment & Commitment (Pro Max Redesign)
class PaymentView extends GetView<CaseFormController> {
  const PaymentView({super.key});

  @override
  Widget build(BuildContext context) {
    controller.currentStep.value = 3;

    return MedicalCaseLayout(
      title: 'Thanh Toán & Cam Kết',
      currentStep: 3,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Summary Section
        AppCard(
          headerTitle: 'Tổng Kết Chi Phí',
          headerIcon: FontAwesomeIcons.fileInvoiceDollar,
          padding: EdgeInsets.zero,
          child: _buildSummaryCard(context),
        ),

        const SizedBox(height: 24),

        // 2. Payment Section
        AppCard(
          headerTitle: 'Thanh Toán',
          headerIcon: FontAwesomeIcons.wallet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin thanh toán và ứng trước',
                style: TextStyle(color: AppColors.slate800, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Advance Payment History
              Obx(() {
                if (controller.advancePaymentHistory.isEmpty)
                  return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử đã ứng:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...controller.advancePaymentHistory.asMap().entries.map((
                      entry,
                    ) {
                      final idx = entry.key + 1;
                      final h = entry.value;
                      final mthd = h.method == AppKeys.transfer
                          ? 'Chuyển khoản'
                          : 'Tiền mặt';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đợt $idx - ${Formatters.formatDate(h.date)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${Formatters.formatCurrency(h.amount)} ($mthd)',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(height: 24, color: AppColors.border),
                  ],
                );
              }),

              // Advance Payment Input
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Obx(
                      () => CustomTextField(
                        label: controller.advancePaymentHistory.isEmpty
                            ? 'Số tiền ứng trước'
                            : 'Số tiền ứng THÊM đợt này',
                        hint: '0',
                        controller: controller.advancePaymentController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.attach_money),
                        onChanged: controller.setAdvancePayment,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Payment Method Selection
              const Text(
                'Phương thức ứng trước',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: SelectionChip(
                        label: 'Tiền mặt',
                        icon: FontAwesomeIcons.moneyBillWave,
                        isSelected:
                            controller.advancePaymentMethod.value ==
                            AppKeys.cash,
                        selectedColor: AppColors.success,
                        selectedBgColor: AppColors.successLight,
                        selectedBorderColor: AppColors.success,
                        onTap: () => controller.advancePaymentMethod.value =
                            AppKeys.cash,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SelectionChip(
                        label: 'Chuyển khoản',
                        icon: FontAwesomeIcons.buildingColumns,
                        isSelected:
                            controller.advancePaymentMethod.value ==
                            AppKeys.transfer,
                        selectedColor: AppColors.primary,
                        selectedBgColor: AppColors.primaryLight,
                        selectedBorderColor: AppColors.primary,
                        onTap: () => controller.advancePaymentMethod.value =
                            AppKeys.transfer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Appointment Section
        AppCard(
          headerTitle: 'Lịch Hẹn Tái Khám',
          headerIcon: FontAwesomeIcons.calendarCheck,
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đặt lịch hẹn tái khám cho thú cưng',
                  style: TextStyle(color: AppColors.slate800, fontSize: 13),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        controller.followUpDate.value = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      } else {
                        // User picked date but cancelled time — use 9:00 default
                        controller.followUpDate.value = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          9,
                          0,
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: controller.followUpDate.value != null
                              ? AppColors.primary
                              : AppColors.slate600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            controller.followUpDate.value != null
                                ? Formatters.formatDateTime(
                                    controller.followUpDate.value!,
                                  )
                                : 'Chọn ngày tái khám (Không bắt buộc)',
                            style: TextStyle(
                              color: controller.followUpDate.value != null
                                  ? AppColors.slate800
                                  : AppColors.slate600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (controller.followUpDate.value != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                controller.followUpDate.value = null,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ),
                if (controller.followUpDate.value != null) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Nội dung tái khám',
                    hint: 'VD: Tiêm vacxin mũi 2, Kiểm tra vết mổ...',
                    initialValue: controller.followUpNote.value,
                    onChanged: (v) => controller.followUpNote.value = v,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 4. Commitment Section
        AppCard(
          headerTitle: 'Cam Kết & Xác Nhận',
          headerIcon: FontAwesomeIcons.signature,
          child: Column(
            children: [
              Obx(
                () => _buildCheckboxTile(
                  value: controller.agreeTreatment.value,
                  onChanged: (v) => controller.agreeTreatment.value = v!,
                  label:
                      'Tôi đồng ý với nhận định, liệu trình điều trị trên và sẽ hợp tác với Bác sỹ trong quá trình điều trị.',
                ),
              ),
              const Divider(height: 24, color: AppColors.border),
              Obx(
                () => _buildCheckboxTile(
                  value: controller.agreeNoComplaint.value,
                  onChanged: (v) => controller.agreeNoComplaint.value = v!,
                  label:
                      'Cam kết không khiếu nại và không yêu cầu bồi thường về sau.',
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Ghi chú nội bộ',
                hint: 'Ghi chú dành cho bác sĩ/thu ngân...',
                maxLines: 3,
                initialValue: controller.notes.value,
                onChanged: (v) => controller.notes.value = v,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng dự kiến',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Obx(
                () => Text(
                  Formatters.formatCurrency(controller.totalEstimate.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Services List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          itemCount: controller.selectedServices.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 24, color: AppColors.border),
          itemBuilder: (context, index) {
            final service = controller.selectedServices[index];
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.serviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate800,
                        ),
                      ),
                      if (service.attachedMedicines.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '+ ${service.attachedMedicines.length} thuốc đi kèm',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'x${service.quantity}',
                  style: const TextStyle(color: AppColors.slate800),
                ),
                const SizedBox(width: 16),
                Text(
                  Formatters.formatCurrency(service.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                ),
              ],
            );
          },
        ),
        const Divider(height: 1, color: AppColors.border),
        // Balance Info
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng đã ứng',
                      style: TextStyle(color: AppColors.slate800),
                    ),
                    const SizedBox(height: 4),
                    Obx(() {
                      final totalAdv =
                          controller.advancePayment.value +
                          controller.newAdvancePaymentInput.value;
                      return Text(
                        totalAdv == 0
                            ? '0'
                            : Formatters.formatCurrency(totalAdv),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Còn lại (sau khi lưu)',
                      style: TextStyle(color: AppColors.slate800),
                    ),
                    const SizedBox(height: 4),
                    Obx(() {
                      final remaining =
                          controller.totalEstimate.value -
                          (controller.advancePayment.value +
                              controller.newAdvancePaymentInput.value);
                      return Text(
                        Formatters.formatCurrency(remaining),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: remaining > 0
                              ? AppColors.error
                              : AppColors.success,
                          fontSize: 16,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.slate900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
