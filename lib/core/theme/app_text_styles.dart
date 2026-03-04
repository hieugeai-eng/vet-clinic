import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Define the typography for the application using Google Fonts (Inter)
class AppTextStyles {
  AppTextStyles._();

  // Basic Font Family
  static final String? fontFamily = GoogleFonts.beVietnamPro().fontFamily;

  // We define dynamic methods to easily apply colors
  static TextStyle light({
    double size = 16,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w300,
    );
  }

  static TextStyle normal({
    double size = 16,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.normal,
    );
  }

  static TextStyle medium({
    double size = 16,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w500,
    );
  }

  static TextStyle semiBold({
    double size = 16,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle bold({
    double size = 16,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle extraBold({
    double size = 16,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w800,
    );
  }

  // Pre-defined commonly used styles for consistency
  static final TextStyle h1 = extraBold(size: 26, color: AppColors.slate900);
  static final TextStyle h2 = bold(size: 22, color: AppColors.slate900);
  static final TextStyle h3 = semiBold(size: 20, color: AppColors.slate900);
  static final TextStyle h4 = semiBold(size: 18, color: AppColors.slate900);
  static final TextStyle h5 = semiBold(size: 16, color: AppColors.slate900);

  static final TextStyle bodyLarge = normal(
    size: 18,
    color: AppColors.slate900,
  );
  static final TextStyle bodyMedium = normal(
    size: 16,
    color: AppColors.slate900,
  );
  static final TextStyle bodySmall = normal(
    size: 14,
    color: AppColors.slate800,
  );

  static final TextStyle caption = medium(size: 13, color: AppColors.slate900);
  static final TextStyle badge = semiBold(size: 12, color: Colors.white);
}
