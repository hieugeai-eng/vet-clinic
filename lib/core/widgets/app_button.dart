import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

enum AppButtonType { primary, secondary, outline, ghost }

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final AppButtonType type;
  final bool isFullWidth;
  final bool isLoading;
  final Color? customColor;
  final EdgeInsetsGeometry padding;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.type = AppButtonType.primary,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    Widget buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Icon(icon, size: 16),
          ),
        Text(
          label,
          style: AppTextStyles.medium(
            size: 13,
            color: type == AppButtonType.primary
                ? Colors.white
                : (customColor ?? Theme.of(context).primaryColor),
          ),
        ),
      ],
    );

    ButtonStyle style;
    switch (type) {
      case AppButtonType.primary:
        style = ElevatedButton.styleFrom(
          backgroundColor: customColor ?? Theme.of(context).primaryColor,
          padding: padding,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        );
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: buttonContent,
        );
      case AppButtonType.outline:
        style = OutlinedButton.styleFrom(
          foregroundColor: customColor ?? Theme.of(context).primaryColor,
          side: BorderSide(
            color: customColor ?? Theme.of(context).primaryColor,
          ),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        );
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: buttonContent,
        );
      case AppButtonType.ghost:
      case AppButtonType.secondary:
        style = TextButton.styleFrom(
          foregroundColor: customColor ?? Theme.of(context).primaryColor,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        );
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: buttonContent,
        );
    }
  }
}
