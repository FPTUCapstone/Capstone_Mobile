import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';

/// Web-aligned Coastal Heritage light palette with automatic dark-mode fallback
/// to [TripMateColors.dark].
@immutable
final class CoastalPalette {
  const CoastalPalette._({
    required this.canvas,
    required this.surface,
    required this.primary,
    required this.primaryHover,
    required this.softAccent,
    required this.accent,
    required this.ink,
    required this.secondary,
    required this.border,
    required this.success,
    required this.warningBg,
    required this.warningText,
    required this.warningBorder,
    required this.error,
    required this.errorBg,
    required this.onPrimary,
  });

  final Color canvas;
  final Color surface;
  final Color primary;
  final Color primaryHover;
  final Color softAccent;
  final Color accent;
  final Color ink;
  final Color secondary;
  final Color border;
  final Color success;
  final Color warningBg;
  final Color warningText;
  final Color warningBorder;
  final Color error;
  final Color errorBg;
  final Color onPrimary;

  static const light = CoastalPalette._(
    canvas: Color(0xFFF7F5EF),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF174B4A),
    primaryHover: Color(0xFF103B39),
    softAccent: Color(0xFFE8F0EA),
    accent: Color(0xFFB96D4C),
    ink: Color(0xFF1C2928),
    secondary: Color(0xFF5B6E69),
    border: Color(0xFFDCE2DD),
    success: Color(0xFF0E9F6E),
    warningBg: Color(0xFFFEF3E2),
    warningText: Color(0xFFB45309),
    warningBorder: Color(0xFFFDE68A),
    error: Color(0xFFE02D4D),
    errorBg: Color(0xFFFDECEF),
    onPrimary: Colors.white,
  );

  static CoastalPalette of(BuildContext context) {
    final c = context.tmColors;
    if (!c.isDark) return light;
    return CoastalPalette._(
      canvas: c.canvas,
      surface: c.surfaceCard,
      primary: c.brandTeal,
      primaryHover: c.brandTealDark,
      softAccent: c.tealSoftContainer,
      accent: c.coralAccessibleText,
      ink: c.textPrimary,
      secondary: c.textSecondary,
      border: c.borderSubtle,
      success: c.success,
      warningBg: c.warningContainer,
      warningText: c.warning,
      warningBorder: c.warning,
      error: c.error,
      errorBg: c.errorContainer,
      onPrimary: c.textOnBrand,
    );
  }
}
