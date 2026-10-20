import 'package:flutter/material.dart';

/// Semantic design tokens for the TripMate Voyager / Adaptive Journey System.
///
/// Anchored by Deep Navy (#00152A) and Deep Teal (#006B5F), matching
/// `stitch_tripmate_adaptive_journey_system/DESIGN.md` and feature palettes.
abstract final class AppColors {
  // Brand Anchors (Matching TripMate Stitch Template)
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
