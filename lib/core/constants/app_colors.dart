import 'package:flutter/material.dart';

/// App color palette - OKADA Vet Clinic (Re-designed with Tailwind-like palette)
class AppColors {
  AppColors._();

  // --- BRAND COLORS ---
  // Primary (Violet)
  static const Color primary = Color(0xFF7C3AED); // violet-600
  static const Color primaryLight = Color(0xFFEDE9FE); // violet-100
  static const Color primaryDark = Color(0xFF5B21B6); // violet-800

  // Secondary (Blue/Cyan)
  static const Color secondary = Color(0xFF2563EB); // blue-600
  static const Color secondaryLight = Color(0xFFDBEAFE); // blue-100
  static const Color secondaryDark = Color(0xFF1E3A8A); // blue-900

  // --- SEMANTIC COLORS ---
  // Success (Green)
  static const Color success = Color(0xFF16A34A); // green-600
  static const Color successLight = Color(0xFFDCFCE7); // green-100
  static const Color successDark = Color(0xFF14532D); // green-900

  // Warning (Amber)
  static const Color warning = Color(0xFFD97706); // amber-600
  static const Color warningLight = Color(0xFFFEF3C7); // amber-100
  static const Color warningDark = Color(0xFF78350F); // amber-900

  // Error/Danger (Red)
  static const Color error = Color(0xFFDC2626); // red-600
  static const Color errorLight = Color(0xFFFEF2F2); // red-100
  static const Color errorDark = Color(0xFF7F1D1D); // red-900

  // Info (Teal/Cyan)
  static const Color info = Color(0xFF0D9488); // teal-600
  static const Color infoLight = Color(0xFFCCFBF1); // teal-100

  // --- NEUTRAL / SLATE COLORS ---
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0); // borders
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8); // icons, hints
  static const Color slate500 = Color(0xFF64748B); // secondary text
  static const Color slate600 = Color(0xFF475569); // readable text
  static const Color slate700 = Color(0xFF334155); // borders dark
  static const Color slate800 = Color(0xFF1E293B); // headers
  static const Color slate900 = Color(0xFF0F172A); // bg dark

  // --- ALIASES FOR THEME ---
  static const Color background =
      slate50; // main bg light (darker than white to contrast AppCards)
  static const Color backgroundDark = slate900; // main bg dark
  static const Color surface = Colors.white; // cards
  static const Color surfaceDark = slate800; // cards dark

  static const Color textPrimary = slate900;
  static const Color textSecondary = slate500;
  static const Color textHint = slate400;
  static const Color textOnPrimary = Colors.white;

  static const Color border = slate200;
  static const Color borderDark = slate700;
  static const Color shadowColor = Color(0x190F172A);

  // Retro-compatibility aliases
  static const Color text = textPrimary;
  static const Color textLight = textHint;
  static const Color sidebarBg = slate900;
  static const Color prognosisGood = success;
  static const Color prognosisBad = error;
  static const Color prognosisUncertain = warning;
}
