import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────
//  AKSA Design Tokens
// ─────────────────────────────────────────────────────

class AksaColors {
  AksaColors._();

  // Brand
  static const primary = Color(0xFF4F46E5);     // Indigo
  static const primaryLight = Color(0xFF818CF8);
  static const secondary = Color(0xFF06B6D4);   // Cyan
  static const accent = Color(0xFF10B981);       // Emerald

  // Risk levels
  static const riskLow = Color(0xFF10B981);
  static const riskMedium = Color(0xFFF59E0B);
  static const riskHigh = Color(0xFFEF4444);

  // Dark background layers
  static const bg = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceCard = Color(0xFF16213E);
  static const surfaceElevated = Color(0xFF1E2A50);

  // Text
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  // Gradients
  static const gradPrimary = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradSuccess = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradWarn = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradDanger = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradCard = LinearGradient(
    colors: [Color(0xFF1E2A50), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────────────
//  Theme
// ─────────────────────────────────────────────────────

ThemeData buildAksaTheme() {
  const colorScheme = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: AksaColors.primary,
    onPrimary: Colors.white,
    secondary: AksaColors.secondary,
    onSecondary: Colors.white,
    surface: AksaColors.surface,
    onSurface: AksaColors.textPrimary,
    error: AksaColors.riskHigh,
    onError: Colors.white,
    surfaceContainerHighest: AksaColors.surfaceElevated,
    outline: Color(0xFF334155),
  );

  final textTheme = GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: AksaColors.textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AksaColors.textPrimary),
      bodyMedium: TextStyle(color: AksaColors.textSecondary),
      bodySmall: TextStyle(color: AksaColors.textMuted),
      labelLarge: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: AksaColors.textSecondary),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AksaColors.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AksaColors.bg,
      foregroundColor: AksaColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: GoogleFonts.inter(
        color: AksaColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AksaColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E293B), width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AksaColors.surface,
      indicatorColor: AksaColors.primary.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AksaColors.primaryLight,
          );
        }
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AksaColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AksaColors.primaryLight);
        }
        return const IconThemeData(color: AksaColors.textMuted);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AksaColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AksaColors.primaryLight,
        side: const BorderSide(color: AksaColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: AksaColors.surfaceElevated,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AksaColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AksaColors.textSecondary),
      hintStyle: const TextStyle(color: AksaColors.textMuted),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1E293B),
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AksaColors.surfaceElevated,
      selectedColor: AksaColors.primary.withOpacity(0.3),
      labelStyle: GoogleFonts.inter(color: AksaColors.textSecondary, fontSize: 12),
      side: const BorderSide(color: Color(0xFF334155)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}