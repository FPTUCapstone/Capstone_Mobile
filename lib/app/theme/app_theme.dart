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
        toolbarHeight: 52,
        backgroundColor: c.surfaceCard,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.displayFont,
          fontSize: 17.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: c.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceCard,
        indicatorColor: c.tealSoftContainer,
        surfaceTintColor: Colors.transparent,
        height: 62,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: AppTypography.uiFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.brandTeal,
            );
          }
          return TextStyle(
            fontFamily: AppTypography.uiFont,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.brandTeal, size: 22);
          }
          return IconThemeData(color: c.textSecondary, size: 21);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.actionPrimary,
          foregroundColor: c.textOnBrand,
          disabledBackgroundColor: c.actionDisabledBg,
          disabledForegroundColor: c.actionDisabledText,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TripMateRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: AppTypography.uiFont,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          side: BorderSide(color: c.borderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TripMateRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.uiFont,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandTeal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.uiFont,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceCard,
        selectedColor: c.tealSoftContainer,
        side: BorderSide(color: c.borderSubtle),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: TextStyle(
          fontFamily: AppTypography.uiFont,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceCard,
        isDense: true,
        hintStyle: TextStyle(
          fontFamily: AppTypography.uiFont,
          fontSize: 13.5,
          color: c.textMuted,
        ),
        labelStyle: TextStyle(
          fontFamily: AppTypography.uiFont,
          fontSize: 13.5,
          color: c.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
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
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          borderSide: BorderSide(color: c.brandTeal, width: 1.5),
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
