import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';

enum StatusBadgeType { success, warning, error, info, neutral, primary }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (type) {
      case StatusBadgeType.success:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        break;
      case StatusBadgeType.warning:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        break;
      case StatusBadgeType.error:
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        break;
      case StatusBadgeType.info:
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        break;
      case StatusBadgeType.primary:
        bgColor = AppColors.primaryLight;
        textColor = AppColors.primary;
        break;
      case StatusBadgeType.neutral:
      default:
        bgColor = AppColors.slate100;
        textColor = AppColors.slate900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTextStyles.medium(size: 10, color: textColor),
      ),
    );
  }
}
