import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light =>
      _buildTheme(TripMateColors.light, Brightness.light);

  static ThemeData get dark =>
      _buildTheme(TripMateColors.dark, Brightness.dark);

  static ThemeData _buildTheme(TripMateColors c, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.isDark ? c.brandTeal : c.brandNavy,
      onPrimary: c.isDark ? c.textOnBrand : Colors.white,
      primaryContainer: c.tealSoftContainer,
      onPrimaryContainer: c.textPrimary,
      secondary: c.brandTeal,
      onSecondary: c.textOnBrand,
      secondaryContainer: c.tealSoftContainer,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.coralAccessibleText,
      onTertiary: c.isDark ? c.textOnCoralBadge : Colors.white,
      tertiaryContainer: c.coralSoftContainer,
      onTertiaryContainer: c.textPrimary,
      error: c.error,
      onError: c.textOnBrand,
      errorContainer: c.errorContainer,
      onErrorContainer: c.error,
      surface: c.canvas,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.borderStrong,
      outlineVariant: c.borderSubtle,
      surfaceContainerLowest: c.surfaceCard,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.surfaceElevated,
      surfaceContainerHigh: c.surfaceElevated,
      surfaceContainerHighest: c.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.canvas,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(c.textPrimary),
      extensions: [c],
      cardTheme: CardThemeData(
        color: c.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.md),
          side: BorderSide(color: c.borderSubtle, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: c.surfaceCard,
        foregroundColor: c.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceCard,
        indicatorColor: c.tealSoftContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: AppTypography.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.brandTeal,
            );
          }
          return TextStyle(
            fontFamily: AppTypography.uiFont,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.brandTeal);
          }
          return IconThemeData(color: c.textSecondary);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.actionPrimary,
          foregroundColor: c.textOnBrand,
          disabledBackgroundColor: c.actionDisabledBg,
          disabledForegroundColor: c.actionDisabledText,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TripMateRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: AppTypography.uiFont,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: c.borderStrong, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TripMateRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.uiFont,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandTeal,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.uiFont,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceCard,
        hintStyle: TextStyle(
          fontFamily: AppTypography.uiFont,
          color: c.textMuted,
        ),
        labelStyle: TextStyle(
          fontFamily: AppTypography.uiFont,
          color: c.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          borderSide: BorderSide(color: c.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          borderSide: BorderSide(color: c.borderSubtle),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          borderSide: BorderSide(color: c.error, width: 1.6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          borderSide: BorderSide(color: c.brandTeal, width: 1.6),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.isDark ? c.surfaceElevated : c.brandNavy,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.uiFont,
          fontSize: 13.5,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
        ),
      ),
    );
  }
}
