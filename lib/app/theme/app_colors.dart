import 'package:flutter/material.dart';

/// Semantic color tokens for the TripMate Voyager / Adaptive Journey System.
///
/// Legacy [AppColors] static constants are preserved during PR 1 so existing
/// un-migrated widgets compile cleanly; new and migrated components should read
/// [TripMateColors] from `Theme.of(context).extension<TripMateColors>()` or
/// `context.tmColors`.
abstract final class AppColors {
  // Brand Anchors (Unified TripMate Coastal Heritage System)
  static const primary = Color(0xFF174B4A); // Coastal Deep Teal
  static const primaryBright = Color(0xFF1F6361); // Coastal Teal Bright
  static const primarySoft = Color(0xFFE8F0EA); // Soft Sage Container
  static const secondary = Color(0xFF174B4A); // Unified Coastal Teal
  static const secondaryDark = Color(0xFF103B39); // Coastal Teal Deep
  static const accent = Color(0xFFB96D4C); // Warm Terracotta Accent
  static const freshGreen = Color(0xFF174B4A); // Calm Coastal Startup Teal
  static const logoNavy = Color(0xFF103B39); // Official Coastal Deep Anchor

  // Neutral & Surfaces
  static const ink = Color(0xFF1C2928); // Calm High-Contrast Coastal Ink
  static const muted = Color(0xFF5B6E69); // Soft Sage Slate
  static const line = Color(0xFFDCE2DD); // Subtle 1px card/divider line
  static const surface = Color(0xFFF7F5EF); // Warm Coastal Ivory Canvas
  static const cardBackground = Color(0xFFFFFFFF); // Crisp white card surface
  static const darkSurface = Color(0xFF103B39);

  // Status & Feedback
  static const success = Color(0xFF0E9F6E); // Calm Emerald success
  static const warning = Color(0xFFB45309); // Warm Amber warning
  static const error = Color(0xFFC8233F); // Muted Crimson error
}

/// Semantic Light & Dark color tokens for TripMate Mobile
/// (Concept B — Refined Travel Editorial).
@immutable
final class TripMateColors extends ThemeExtension<TripMateColors> {
  const TripMateColors({
    required this.brandNavy,
    required this.brandTeal,
    required this.brandTealDark,
    required this.brandCoral,
    required this.coralAccessibleText,
    required this.coralSoftContainer,
    required this.tealSoftContainer,
    required this.canvas,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnBrand,
    required this.textOnCoralBadge,
    required this.actionPrimary,
    required this.actionPrimaryPressed,
    required this.actionDisabledBg,
    required this.actionDisabledText,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.photoOverlayTop,
    required this.photoOverlayBottom,
    required this.mapRouteLine,
    required this.mapRouteSecondary,
    required this.mapSurface,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.isDark,
  });

  // Official Brand Anchors
  final Color brandNavy;
  final Color brandTeal;
  final Color brandTealDark;
  final Color brandCoral;

  // Accessible Warm Coral & Teal Containers
  final Color coralAccessibleText;
  final Color coralSoftContainer;
  final Color tealSoftContainer;

  // Surfaces & Canvas
  final Color canvas;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceOverlay;
  final Color borderSubtle;
  final Color borderStrong;

  // Typography Hierarchy
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnBrand;
  final Color textOnCoralBadge;

  // Interactive Actions
  final Color actionPrimary;
  final Color actionPrimaryPressed;
  final Color actionDisabledBg;
  final Color actionDisabledText;

  // Semantic Feedback
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;

  // Photo & Map Overlays
  final Color photoOverlayTop;
  final Color photoOverlayBottom;
  final Color mapRouteLine;
  final Color mapRouteSecondary;
  final Color mapSurface;

  // Skeletons
  final Color shimmerBase;
  final Color shimmerHighlight;

  final bool isDark;

  static const TripMateColors light = TripMateColors(
    brandNavy: Color(0xFF103B39),
    brandTeal: Color(0xFF174B4A),
    brandTealDark: Color(0xFF103B39),
    brandCoral: Color(0xFF995436),
    coralAccessibleText: Color(0xFF995436),
    coralSoftContainer: Color(0xFFF6EDE8),
    tealSoftContainer: Color(0xFFE8F0EA),
    canvas: Color(0xFFF7F5EF),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDEAE1),
    surfaceOverlay: Color(0xF5FFFFFF),
    borderSubtle: Color(0xFFDCE2DD),
    borderStrong: Color(0xFFC4CEC8),
    textPrimary: Color(0xFF1C2928),
    textSecondary: Color(0xFF536560),
    textMuted: Color(0xFF5B6E69),
    textOnBrand: Color(0xFFFFFFFF),
    textOnCoralBadge: Color(0xFFFFFFFF),
    actionPrimary: Color(0xFF174B4A),
    actionPrimaryPressed: Color(0xFF103B39),
    actionDisabledBg: Color(0xFFE6E3DA),
    actionDisabledText: Color(0xFF7B8B86),
    success: Color(0xFF0E9F6E),
    successContainer: Color(0xFFE5F6EF),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3E2),
    error: Color(0xFFC8233F),
    errorContainer: Color(0xFFFDECEF),
    info: Color(0xFF174B4A),
    infoContainer: Color(0xFFE8F0EA),
    photoOverlayTop: Color(0x26102827),
    photoOverlayBottom: Color(0xBF102827),
    mapRouteLine: Color(0xFF174B4A),
    mapRouteSecondary: Color(0xFFB96D4C),
    mapSurface: Color(0xFFE8F0EA),
    shimmerBase: Color(0xFFEBE8DF),
    shimmerHighlight: Color(0xFFF6F4EE),
    isDark: false,
  );

  static const TripMateColors dark = TripMateColors(
    brandNavy: Color(0xFF103B39),
    brandTeal: Color(0xFF4FB3A7),
    brandTealDark: Color(0xFF338C82),
    brandCoral: Color(0xFFD89272),
    coralAccessibleText: Color(0xFFE5A486),
    coralSoftContainer: Color(0xFF3A241B),
    tealSoftContainer: Color(0xFF143533),
    canvas: Color(0xFF0E1716),
    surfaceCard: Color(0xFF152322),
    surfaceElevated: Color(0xFF1D302E),
    surfaceOverlay: Color(0xEE152322),
    borderSubtle: Color(0xFF273E3C),
    borderStrong: Color(0xFF3A5754),
    textPrimary: Color(0xFFF4F3EE),
    textSecondary: Color(0xFFB6C5C0),
    textMuted: Color(0xFF8FA39D),
    textOnBrand: Color(0xFF071615),
    textOnCoralBadge: Color(0xFF101C1B),
    actionPrimary: Color(0xFF4FB3A7),
    actionPrimaryPressed: Color(0xFF3B9A8F),
    actionDisabledBg: Color(0xFF1E302E),
    actionDisabledText: Color(0xFF6E847E),
    success: Color(0xFF4ADEA0),
    successContainer: Color(0xFF103428),
    warning: Color(0xFFFFB74D),
    warningContainer: Color(0xFF3B2810),
    error: Color(0xFFFF7A70),
    errorContainer: Color(0xFF441818),
    info: Color(0xFF7CB4FF),
    infoContainer: Color(0xFF162A47),
    photoOverlayTop: Color(0x4D0A1413),
    photoOverlayBottom: Color(0xDB0A1413),
    mapRouteLine: Color(0xFF4FB3A7),
    mapRouteSecondary: Color(0xFFD89272),
    mapSurface: Color(0xFF142826),
    shimmerBase: Color(0xFF1B2E2C),
    shimmerHighlight: Color(0xFF263E3C),
    isDark: true,
  );

  @override
  TripMateColors copyWith({
    Color? brandNavy,
    Color? brandTeal,
    Color? brandTealDark,
    Color? brandCoral,
    Color? coralAccessibleText,
    Color? coralSoftContainer,
    Color? tealSoftContainer,
    Color? canvas,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceOverlay,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnBrand,
    Color? textOnCoralBadge,
    Color? actionPrimary,
    Color? actionPrimaryPressed,
    Color? actionDisabledBg,
    Color? actionDisabledText,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? infoContainer,
    Color? photoOverlayTop,
    Color? photoOverlayBottom,
    Color? mapRouteLine,
    Color? mapRouteSecondary,
    Color? mapSurface,
    Color? shimmerBase,
    Color? shimmerHighlight,
    bool? isDark,
  }) {
    return TripMateColors(
      brandNavy: brandNavy ?? this.brandNavy,
      brandTeal: brandTeal ?? this.brandTeal,
      brandTealDark: brandTealDark ?? this.brandTealDark,
      brandCoral: brandCoral ?? this.brandCoral,
      coralAccessibleText: coralAccessibleText ?? this.coralAccessibleText,
      coralSoftContainer: coralSoftContainer ?? this.coralSoftContainer,
      tealSoftContainer: tealSoftContainer ?? this.tealSoftContainer,
      canvas: canvas ?? this.canvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      textOnCoralBadge: textOnCoralBadge ?? this.textOnCoralBadge,
      actionPrimary: actionPrimary ?? this.actionPrimary,
      actionPrimaryPressed: actionPrimaryPressed ?? this.actionPrimaryPressed,
      actionDisabledBg: actionDisabledBg ?? this.actionDisabledBg,
      actionDisabledText: actionDisabledText ?? this.actionDisabledText,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      photoOverlayTop: photoOverlayTop ?? this.photoOverlayTop,
      photoOverlayBottom: photoOverlayBottom ?? this.photoOverlayBottom,
      mapRouteLine: mapRouteLine ?? this.mapRouteLine,
      mapRouteSecondary: mapRouteSecondary ?? this.mapRouteSecondary,
      mapSurface: mapSurface ?? this.mapSurface,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  TripMateColors lerp(ThemeExtension<TripMateColors>? other, double t) {
    if (other is! TripMateColors) return this;
    Color lerpColor(Color a, Color b) =>
        Color.lerp(a, b, t) ?? (t < 0.5 ? a : b);
    return TripMateColors(
      brandNavy: lerpColor(brandNavy, other.brandNavy),
      brandTeal: lerpColor(brandTeal, other.brandTeal),
      brandTealDark: lerpColor(brandTealDark, other.brandTealDark),
      brandCoral: lerpColor(brandCoral, other.brandCoral),
      coralAccessibleText: lerpColor(
        coralAccessibleText,
        other.coralAccessibleText,
      ),
      coralSoftContainer: lerpColor(
        coralSoftContainer,
        other.coralSoftContainer,
      ),
      tealSoftContainer: lerpColor(tealSoftContainer, other.tealSoftContainer),
      canvas: lerpColor(canvas, other.canvas),
      surfaceCard: lerpColor(surfaceCard, other.surfaceCard),
      surfaceElevated: lerpColor(surfaceElevated, other.surfaceElevated),
      surfaceOverlay: lerpColor(surfaceOverlay, other.surfaceOverlay),
      borderSubtle: lerpColor(borderSubtle, other.borderSubtle),
      borderStrong: lerpColor(borderStrong, other.borderStrong),
      textPrimary: lerpColor(textPrimary, other.textPrimary),
      textSecondary: lerpColor(textSecondary, other.textSecondary),
      textMuted: lerpColor(textMuted, other.textMuted),
      textOnBrand: lerpColor(textOnBrand, other.textOnBrand),
      textOnCoralBadge: lerpColor(textOnCoralBadge, other.textOnCoralBadge),
      actionPrimary: lerpColor(actionPrimary, other.actionPrimary),
      actionPrimaryPressed: lerpColor(
        actionPrimaryPressed,
        other.actionPrimaryPressed,
      ),
      actionDisabledBg: lerpColor(actionDisabledBg, other.actionDisabledBg),
      actionDisabledText: lerpColor(
        actionDisabledText,
        other.actionDisabledText,
      ),
      success: lerpColor(success, other.success),
      successContainer: lerpColor(successContainer, other.successContainer),
      warning: lerpColor(warning, other.warning),
      warningContainer: lerpColor(warningContainer, other.warningContainer),
      error: lerpColor(error, other.error),
      errorContainer: lerpColor(errorContainer, other.errorContainer),
      info: lerpColor(info, other.info),
      infoContainer: lerpColor(infoContainer, other.infoContainer),
      photoOverlayTop: lerpColor(photoOverlayTop, other.photoOverlayTop),
      photoOverlayBottom: lerpColor(
        photoOverlayBottom,
        other.photoOverlayBottom,
      ),
      mapRouteLine: lerpColor(mapRouteLine, other.mapRouteLine),
      mapRouteSecondary: lerpColor(mapRouteSecondary, other.mapRouteSecondary),
      mapSurface: lerpColor(mapSurface, other.mapSurface),
      shimmerBase: lerpColor(shimmerBase, other.shimmerBase),
      shimmerHighlight: lerpColor(shimmerHighlight, other.shimmerHighlight),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Convenience accessor for [TripMateColors] from any [BuildContext].
extension TripMateThemeContext on BuildContext {
  TripMateColors get tmColors =>
      Theme.of(this).extension<TripMateColors>() ?? TripMateColors.light;
}
