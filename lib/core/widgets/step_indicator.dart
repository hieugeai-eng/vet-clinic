import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';

class StepItem {
  final String title;
  final bool isDone;
  final bool isActive;

  StepItem({required this.title, this.isDone = false, this.isActive = false});
}

class StepIndicator extends StatelessWidget {
  final List<StepItem> steps;

  const StepIndicator({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: steps.asMap().entries.map((entry) {
            int index = entry.key;
            StepItem step = entry.value;

            Color bgColor = Colors.transparent;
            Color textColor = AppColors.slate600; // default (inactive)
            Color circleBorderParams = AppColors.slate600;
            Color circleTextParams = AppColors.slate600;
            Color circleBgParams = Colors.transparent;
            String circleText = '${index + 1}';

            if (step.isActive) {
              bgColor = AppColors.primary;
              textColor = Colors.white;
              circleBorderParams = Colors.white;
              circleTextParams = AppColors.primary;
              circleBgParams = Colors.white;
            } else if (step.isDone) {
              bgColor = AppColors.successLight;
              textColor = AppColors.success;
              circleBorderParams = AppColors.success;
              circleTextParams = Colors.white;
              circleBgParams = AppColors.success;
              circleText = '✓';
            }

            return Container(
              margin: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleBgParams,
                      border: Border.all(color: circleBorderParams, width: 1.5),
                    ),
                    child: Text(
                      circleText,
                      style: AppTextStyles.bold(
                        size: 10,
                        color: circleTextParams,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    step.title,
                    style: AppTextStyles.medium(size: 12, color: textColor)
                        .copyWith(
                          fontWeight: step.isActive || step.isDone
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
