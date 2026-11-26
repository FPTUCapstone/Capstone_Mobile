import 'package:flutter/material.dart';

/// Editorial & functional typography pairing for TripMate Mobile:
/// - Display / Hero / Headline / Large Titles: `BricolageGrotesque`
/// - UI / Body / Labels / Tabular Prices: `Manrope`
///
/// Both bundled fonts are SIL OFL 1.1 with verified Vietnamese & `₫` coverage.
abstract final class AppTypography {
  static const displayFont = 'BricolageGrotesque';
  static const uiFont = 'Manrope';

  /// Default UI font family retained for backwards-compatible callers.
  static const fontFamily = uiFont;

  static TextTheme textTheme(Color foreground) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 24,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 22,
        height: 1.20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 20,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 18.5,
        height: 1.24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFont,
        color: foreground,
        fontSize: 17.5,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 15,
        height: 1.32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleSmall: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 14.5,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 12,
        height: 1.38,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 13.5,
        height: 1.20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
      ),
      labelMedium: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        fontFamily: uiFont,
        color: foreground,
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static TextStyle price(Color color, {double fontSize = 15.5}) => TextStyle(
    fontFamily: uiFont,
    color: color,
    fontSize: fontSize,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
