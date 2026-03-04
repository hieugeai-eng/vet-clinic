import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,

    // Áp dụng Google Fonts (Be Vietnam Pro) cho toàn bộ TextTheme để dễ đọc tiếng Việt hơn
    textTheme: GoogleFonts.beVietnamProTextTheme(ThemeData.light().textTheme)
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 39,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
          displayMedium: const TextStyle(
            fontSize: 35,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
          displaySmall: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
          headlineLarge: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          headlineMedium: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          headlineSmall: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
          titleMedium: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          titleSmall: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          bodyLarge: const TextStyle(fontSize: 19, color: AppColors.slate900),
          bodyMedium: const TextStyle(fontSize: 17, color: AppColors.slate900),
          bodySmall: const TextStyle(fontSize: 17, color: AppColors.slate900),
          labelLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          labelMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
          labelSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.slate800,
          ),
        ),

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.slate900,
      onError: Colors.white,
    ),

    // AppBar Theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.slate900,
      iconTheme: IconThemeData(color: AppColors.slate900),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shadowColor: AppColors.shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(
        color: AppColors.slate800,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: AppColors.slate600, fontSize: 17),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate600,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.surface;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: AppColors.slate400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primaryLight,
      labelStyle: const TextStyle(
        color: AppColors.slate900,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primaryDark,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );

  // Dark Theme (Basic skeleton for future)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryLight,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    textTheme: GoogleFonts.beVietnamProTextTheme(ThemeData.dark().textTheme),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
      onPrimary: AppColors.slate900,
      onSecondary: AppColors.slate900,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderDark),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
    ),
  );
}
