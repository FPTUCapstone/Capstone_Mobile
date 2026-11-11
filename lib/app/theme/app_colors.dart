import 'package:flutter/material.dart';

/// Semantic color tokens for the TripMate Voyager / Adaptive Journey System.
///
/// Legacy [AppColors] static constants are preserved during PR 1 so existing
/// un-migrated widgets compile cleanly; new and migrated components should read
/// [TripMateColors] from `Theme.of(context).extension<TripMateColors>()` or
/// `context.tmColors`.
abstract final class AppColors {
  // Brand Anchors (Matching TripMate Coastal Heritage & Editorial Baseline)
  static const primary = Color(0xFF00152A); // brandNavy #00152A
  static const primaryBright = Color(0xFF102A43); // Navy Light
  static const primarySoft = Color(0xFFE6F4F1); // Mint Soft / Teal Container
  static const secondary = Color(0xFF006B5F); // brandTeal #006B5F
  static const secondaryDark = Color(0xFF00544A); // Teal Dark
  static const accent = Color(0xFFFF7043); // brandCoral #FF7043
  static const freshGreen = Color(
    0xFF00B074,
  ); // Fresh Vibrant Green (Startup/Splash)
  static const logoNavy = Color(0xFF122E43); // Official Brand Oceanic Navy

  // Neutral & Surfaces
  static const ink = Color(0xFF102A43); // High-contrast ink
  static const muted = Color(0xFF64748B); // Slate Muted
  static const line = Color(0xFFE2E8F0); // Subtle 1px card/divider line
  static const surface = Color(0xFFF8FAFC); // surfaceBg #F8FAFC
  static const cardBackground = Color(0xFFFFFFFF); // Pure white surface
  static const darkSurface = Color(0xFF00152A);

  // Status & Feedback
  static const success = Color(0xFF059669); // Emerald success
  static const warning = Color(0xFFD97706); // Amber warning
  static const error = Color(0xFFBA1A1A); // Crimson / Coral Red error
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
    brandNavy: Color(0xFF00152A),
    brandTeal: Color(0xFF006B5F),
    brandTealDark: Color(0xFF004F46),
    brandCoral: Color(0xFFFF7043),
    coralAccessibleText: Color(0xFFB83D18),
    coralSoftContainer: Color(0xFFFFEFE9),
    tealSoftContainer: Color(0xFFE3F1EE),
    canvas: Color(0xFFF5F6F2),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFECEEE8),
    surfaceOverlay: Color(0xF2FFFFFF),
    borderSubtle: Color(0xFFE1E4DC),
    borderStrong: Color(0xFFC8CEC2),
    textPrimary: Color(0xFF00152A),
    textSecondary: Color(0xFF52606D),
    textMuted: Color(0xFF63717E),
    textOnBrand: Color(0xFFFFFFFF),
    textOnCoralBadge: Color(0xFF00152A),
    actionPrimary: Color(0xFF006B5F),
    actionPrimaryPressed: Color(0xFF004F46),
    actionDisabledBg: Color(0xFFE4E7E0),
    actionDisabledText: Color(0xFF75808A),
    success: Color(0xFF0E7C5B),
    successContainer: Color(0xFFE2F5EE),
    warning: Color(0xFF9C5100),
    warningContainer: Color(0xFFFFF2DF),
    error: Color(0xFFB42318),
    errorContainer: Color(0xFFFEE4E2),
    info: Color(0xFF0B57D0),
    infoContainer: Color(0xFFE8F0FE),
    photoOverlayTop: Color(0x3300152A),
    photoOverlayBottom: Color(0xCC00152A),
    mapRouteLine: Color(0xFF006B5F),
    mapRouteSecondary: Color(0xFFFF7043),
    mapSurface: Color(0xFFE9EFEA),
    shimmerBase: Color(0xFFE6E9E1),
    shimmerHighlight: Color(0xFFF3F5EF),
    isDark: false,
  );

  static const TripMateColors dark = TripMateColors(
    brandNavy: Color(0xFF00152A),
    brandTeal: Color(0xFF33B2A3),
    brandTealDark: Color(0xFF1E8F82),
    brandCoral: Color(0xFFFF7043),
    coralAccessibleText: Color(0xFFFF8F6B),
    coralSoftContainer: Color(0xFF3D2118),
    tealSoftContainer: Color(0xFF103834),
    canvas: Color(0xFF09131F),
    surfaceCard: Color(0xFF102030),
    surfaceElevated: Color(0xFF172B3F),
    surfaceOverlay: Color(0xEE102030),
    borderSubtle: Color(0xFF23384D),
    borderStrong: Color(0xFF354E68),
    textPrimary: Color(0xFFF4F6F1),
    textSecondary: Color(0xFFB6C3CE),
    textMuted: Color(0xFF8FA2B2),
    textOnBrand: Color(0xFF041418),
    textOnCoralBadge: Color(0xFF00152A),
    actionPrimary: Color(0xFF33B2A3),
    actionPrimaryPressed: Color(0xFF289689),
    actionDisabledBg: Color(0xFF1C2E40),
    actionDisabledText: Color(0xFF6B8094),
    success: Color(0xFF4ADEA0),
    successContainer: Color(0xFF103428),
    warning: Color(0xFFFFB74D),
    warningContainer: Color(0xFF3B2810),
    error: Color(0xFFFF7A70),
    errorContainer: Color(0xFF441818),
    info: Color(0xFF7CB4FF),
    infoContainer: Color(0xFF162A47),
    photoOverlayTop: Color(0x4D000D1A),
    photoOverlayBottom: Color(0xDB000D1A),
    mapRouteLine: Color(0xFF43CBB9),
    mapRouteSecondary: Color(0xFFFF8A65),
    mapSurface: Color(0xFF112636),
    shimmerBase: Color(0xFF1A2D40),
    shimmerHighlight: Color(0xFF243B52),
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
    return TripMateColors(
      brandNavy: Color.lerp(brandNavy, other.brandNavy, t)!,
      brandTeal: Color.lerp(brandTeal, other.brandTeal, t)!,
      brandTealDark: Color.lerp(brandTealDark, other.brandTealDark, t)!,
      brandCoral: Color.lerp(brandCoral, other.brandCoral, t)!,
      coralAccessibleText: Color.lerp(
        coralAccessibleText,
        other.coralAccessibleText,
        t,
      )!,
      coralSoftContainer: Color.lerp(
        coralSoftContainer,
        other.coralSoftContainer,
        t,
      )!,
      tealSoftContainer: Color.lerp(
        tealSoftContainer,
        other.tealSoftContainer,
        t,
      )!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
      textOnCoralBadge: Color.lerp(
        textOnCoralBadge,
        other.textOnCoralBadge,
        t,
      )!,
      actionPrimary: Color.lerp(actionPrimary, other.actionPrimary, t)!,
      actionPrimaryPressed: Color.lerp(
        actionPrimaryPressed,
        other.actionPrimaryPressed,
        t,
      )!,
      actionDisabledBg: Color.lerp(
        actionDisabledBg,
        other.actionDisabledBg,
        t,
      )!,
      actionDisabledText: Color.lerp(
        actionDisabledText,
        other.actionDisabledText,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      photoOverlayTop: Color.lerp(photoOverlayTop, other.photoOverlayTop, t)!,
      photoOverlayBottom: Color.lerp(
        photoOverlayBottom,
        other.photoOverlayBottom,
        t,
      )!,
      mapRouteLine: Color.lerp(mapRouteLine, other.mapRouteLine, t)!,
      mapRouteSecondary: Color.lerp(
        mapRouteSecondary,
        other.mapRouteSecondary,
        t,
      )!,
      mapSurface: Color.lerp(mapSurface, other.mapSurface, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Convenience accessor for [TripMateColors] from any [BuildContext].
extension TripMateThemeContext on BuildContext {
  TripMateColors get tmColors =>
      Theme.of(this).extension<TripMateColors>() ?? TripMateColors.light;
}
