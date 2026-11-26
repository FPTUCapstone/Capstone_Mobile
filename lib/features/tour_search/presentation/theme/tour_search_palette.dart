import 'package:flutter/material.dart';

/// Feature-local color palette for Tour Search screens.
///
/// Uses the same teal/navy/emerald design language as the Stitch UI reference,
/// constrained to constants for consistent visual identity.
abstract final class TourSearchPalette {
  // ── Brand / Header (Unified Coastal Heritage) ────────────────────────
  static const teal = Color(0xFF174B4A);
  static const tealDark = Color(0xFF103B39);
  static const tealSoft = Color(0xFFE8F0EA);

  // ── Text / Titles ────────────────────────────────────────────────────
  static const navy = Color(0xFF1C2928);
  static const navyLight = Color(0xFF3E524E);

  // ── Surface / Containers ─────────────────────────────────────────────
  static const background = Color(0xFFF7F5EF);
  static const cardBorder = Color(0xFFDCE2DD);
  static const line = Color(0xFFEDEAE1);

  // ── Status ───────────────────────────────────────────────────────────
  static const available = Color(0xFF0E9F6E);
  static const soldOut = Color(0xFFC8233F);
  static const warning = Color(0xFFB45309);
  static const muted = Color(0xFF5B6E69);
  static const accent = Color(0xFFB96D4C);
}
