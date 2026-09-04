import 'dart:io';
import 'package:flutter/material.dart';

/// App theme definitions — Modern Material 3 with elegant Dark, Light, and System modes.
/// Includes Windows typography enhancements with Microsoft YaHei UI / Segoe UI font fallbacks.
class AppTheme {
  // Brand accent seeds selectable in Settings: indigo / teal / purple / orange.
  static const accentSeeds = [
    Color(0xFF4F46E5),
    Color(0xFF0D9488),
    Color(0xFF9333EA),
    Color(0xFFEA580C),
  ];

  static Color _seedFor(int accent) =>
      accentSeeds[accent.clamp(0, accentSeeds.length - 1)];

  static const List<String> fontFallbacks = [
    'Microsoft YaHei UI',
    'Segoe UI Variable Display',
    'Segoe UI',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans SC',
    'system-ui',
    'sans-serif',
  ];

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light()).textTheme;

    return base.apply(
      fontFamilyFallback: fontFallbacks,
    ).copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        letterSpacing: 0.1,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        letterSpacing: 0.1,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData light({int accent = 0}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedFor(accent),
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAFC), // Slate-50 clean background
      surfaceContainerLowest: const Color(0xFFFFFFFF), // Pure white cards
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFE2E8F0),
      surfaceContainerHighest: const Color(0xFFCBD5E1),
      onSurface: const Color(0xFF0F172A), // Slate-900 high contrast text
      onSurfaceVariant: const Color(0xFF475569), // Slate-600 secondary text
      primary: const Color(0xFF4338CA), // Indigo-700
      onPrimary: Colors.white,
    );

    return _buildThemeData(scheme, Brightness.light);
  }

  static ThemeData dark({int accent = 0}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedFor(accent),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A), // Slate-900 dark background
      surfaceContainerLowest: const Color(0xFF0B0F19),
      surfaceContainerLow: const Color(0xFF1E293B), // Slate-800 cards
      surfaceContainer: const Color(0xFF334155),
      surfaceContainerHigh: const Color(0xFF475569),
      primary: const Color(0xFF818CF8), // Indigo-400
      onPrimary: const Color(0xFF0F172A),
    );

    return _buildThemeData(scheme, Brightness.dark);
  }

  static ThemeData _buildThemeData(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final isWindows = Platform.isWindows;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamilyFallback: fontFallbacks,
      textTheme: _buildTextTheme(brightness),
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: isWindows
          ? VisualDensity.compact
          : VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamilyFallback: fontFallbacks,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : const Color(0xFF94A3B8),
            width: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFCBD5E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFCBD5E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFCBD5E1),
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant.withOpacity(0.8),
        ),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(
          fontFamilyFallback: fontFallbacks,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamilyFallback: fontFallbacks,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 2,
        indicatorColor: scheme.primaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
