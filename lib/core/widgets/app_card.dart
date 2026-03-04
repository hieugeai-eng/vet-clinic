import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final IconData? headerIcon;
  final Color? headerIconColor;
  final String? headerTitle;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Widget? trailingHeader;

  const AppCard({
    super.key,
    required this.child,
    this.headerIcon,
    this.headerIconColor,
    this.headerTitle,
    this.padding = const EdgeInsets.all(12),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.trailingHeader,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerTitle != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors
                    .slate100, // Slightly darker than slate50 for contrast
                border: Border(bottom: BorderSide(color: AppColors.border)),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(10),
                ), // Keep in consistent with parent border radius
              ),
              child: Row(
                children: [
                  if (headerIcon != null) ...[
                    Icon(
                      headerIcon,
                      size: 18,
                      color: headerIconColor ?? AppColors.slate800,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      headerTitle!,
                      style: AppTextStyles.bold(
                        size: 15,
                        color: AppColors.slate900,
                      ).copyWith(letterSpacing: 0.5),
                    ),
                  ),
                  if (trailingHeader != null) trailingHeader!,
                ],
              ),
            ),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
