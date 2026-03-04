import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Step indicator widget for multi-step forms
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? labels;
  final Function(int)? onTap;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels,
    this.onTap,
  });

  static const defaultLabels = [
    'Thông tin',
    'Khám lâm sàng',
    'Chẩn đoán',
    'Thanh toán',
  ];

  @override
  Widget build(BuildContext context) {
    final stepLabels = labels ?? defaultLabels;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? AppColors.primary : AppColors.border,
              ),
            );
          } else {
            // Step circle
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            final isCurrent = stepIndex == currentStep;

            return InkWell(
              onTap: onTap != null ? () => onTap!(stepIndex) : null,
              borderRadius: BorderRadius.circular(32),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _buildStep(
                  number: stepIndex + 1,
                  label: stepLabels.length > stepIndex
                      ? stepLabels[stepIndex]
                      : '',
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                ),
              ),
            );
          }
        }),
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String label,
    required bool isCompleted,
    required bool isCurrent,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isCompleted) {
      bgColor = AppColors.primary;
      textColor = AppColors.textOnPrimary;
      borderColor = AppColors.primary;
    } else if (isCurrent) {
      bgColor = AppColors.surface;
      textColor = AppColors.primary;
      borderColor = AppColors.primary;
    } else {
      bgColor = AppColors.surface;
      textColor = AppColors.textLight;
      borderColor = AppColors.border;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: AppColors.textOnPrimary,
                  )
                : Text(
                    number.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
