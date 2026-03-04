import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Professional TextField with modern styling
Widget ProTextField({
  TextEditingController? controller,
  String? label,
  String? labelText,
  String? hint,
  String? hintText,
  IconData? prefixIcon,
  Widget? prefix,
  Widget? suffix,
  Widget? suffixIcon,
  String? suffixText,
  bool obscureText = false,
  bool enabled = true,
  bool readOnly = false,
  int maxLines = 1,
  int? minLines,
  int? maxLength,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
  void Function()? onTap,
  void Function(String)? onFieldSubmitted,
  FocusNode? focusNode,
  TextAlign textAlign = TextAlign.start,
  TextStyle? style,
  InputDecoration? decoration,
  bool expands = false,
  String? initialValue,
  bool autofocus = false,
}) {
  final effectiveLabel = label ?? labelText;
  final effectiveHint = hint ?? hintText;
  final effectiveSuffix =
      suffix ?? (suffixText != null ? Text(suffixText) : null);

  return TextFormField(
    controller: controller,
    initialValue: controller == null ? initialValue : null,
    obscureText: obscureText,
    enabled: enabled,
    readOnly: readOnly,
    maxLines: maxLines,
    minLines: minLines,
    maxLength: maxLength,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    onChanged: onChanged,
    onTap: onTap,
    onFieldSubmitted: onFieldSubmitted,
    focusNode: focusNode,
    textAlign: textAlign,
    expands: expands,
    autofocus: autofocus,
    style: style ?? const TextStyle(fontSize: 15),
    decoration:
        decoration ??
        InputDecoration(
          labelText: effectiveLabel,
          hintText: effectiveHint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : prefix,
          suffix: effectiveSuffix,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
  );
}

/// Professional Info Card with header and content
Widget ProInfoCard({
  required Widget child,
  String? title,
  EdgeInsets? padding,
  Color? backgroundColor,
  EdgeInsets? margin,
}) {
  return Container(
    margin: margin,
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        child,
      ],
    ),
  );
}

/// Professional Section Header
Widget ProSectionHeader({
  required String title,
  String? subtitle,
  Widget? trailing,
  Widget? action,
  IconData? icon,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade900),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing,
        if (action != null) action,
      ],
    ),
  );
}

/// Professional Selection Card (checkbox/radio style)
Widget ProSelectionCard({
  String? title,
  String? label,
  String? subtitle,
  String? description,
  bool selected = false,
  bool isSelected = false,
  VoidCallback? onTap,
  IconData? iconData,
  Widget? icon,
  Widget? trailing,
  Color? activeColor,
  Color? borderColor,
}) {
  final effectiveTitle = title ?? label ?? '';
  final effectiveSelected = selected || isSelected;
  final effectiveColor = activeColor ?? AppColors.primary;
  final effectiveSubtitle = subtitle ?? description;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: effectiveSelected
            ? effectiveColor.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effectiveSelected
              ? effectiveColor
              : (borderColor ?? Colors.grey.shade300),
          width: effectiveSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            icon,
            const SizedBox(width: 12),
          ] else if (iconData != null) ...[
            Icon(
              iconData,
              color: effectiveSelected ? effectiveColor : Colors.grey.shade900,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: effectiveSelected
                        ? effectiveColor
                        : AppColors.textPrimary,
                  ),
                ),
                if (effectiveSubtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      effectiveSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (effectiveSelected)
            Icon(Icons.check_circle, color: effectiveColor, size: 24),
        ],
      ),
    ),
  );
}
