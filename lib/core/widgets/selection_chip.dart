import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';

class SelectionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color selectedBgColor;
  final Color selectedBorderColor;
  final Color? unselectedBorderThemeColor;
  final bool isDashed;

  const SelectionChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.selectedColor = AppColors.error, // Default red as .sel in mockup
    this.selectedBgColor = AppColors.errorLight,
    this.selectedBorderColor = const Color(0xFFFECACA), // red-200
    this.unselectedBorderThemeColor,
    this.isDashed = false,
  });

  /// Factory for Green selection chip
  factory SelectionChip.success({
    required String label,
    IconData? icon,
    bool isSelected = false,
    VoidCallback? onTap,
    bool isDashed = false,
  }) {
    return SelectionChip(
      label: label,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
      isDashed: isDashed,
      selectedColor: AppColors.success,
      selectedBgColor: AppColors.successLight,
      selectedBorderColor: const Color(0xFF86EFAC),
    );
  }

  /// Factory for Amber selection chip
  factory SelectionChip.warning({
    required String label,
    IconData? icon,
    bool isSelected = false,
    VoidCallback? onTap,
    bool isDashed = false,
  }) {
    return SelectionChip(
      label: label,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
      isDashed: isDashed,
      selectedColor: AppColors.warning,
      selectedBgColor: AppColors.warningLight,
      selectedBorderColor: const Color(0xFFFDE68A),
    );
  }

  /// Factory for Primary/Purple selection chip
  factory SelectionChip.primary({
    required String label,
    IconData? icon,
    bool isSelected = false,
    VoidCallback? onTap,
    bool isDashed = false,
  }) {
    return SelectionChip(
      label: label,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
      isDashed: isDashed,
      selectedColor: AppColors.primary,
      selectedBgColor: AppColors.primaryLight,
      selectedBorderColor: const Color(0xFFC4B5FD),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: isDashed
              ? Border.all(
                  color: isSelected
                      ? selectedBorderColor
                      : (unselectedBorderThemeColor ??
                            AppColors.info), // Dashed usually teal in mockup
                  style: BorderStyle
                      .none, // Flutter doesn't support solid dashed border easily without CustomPaint, but we simulate it or ignore
                )
              : Border.all(
                  color: isSelected ? selectedBorderColor : AppColors.border,
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? selectedColor : AppColors.slate800,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style:
                    AppTextStyles.medium(
                      size: 15,
                      color: isSelected ? selectedColor : AppColors.slate900,
                    ).copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
