import 'package:flutter/material.dart';

/// Feature-local color palette for Tour Search screens.
///
/// Uses the same teal/navy/emerald design language as the Stitch UI reference,
/// constrained to constants for consistent visual identity.
abstract final class TourSearchPalette {
  // ── Brand / Header ───────────────────────────────────────────────────
  static const teal = Color(0xFF006B5F);
  static const tealDark = Color(0xFF00544A);
  static const tealSoft = Color(0xFFE6F4F1);

  // ── Text / Titles ────────────────────────────────────────────────────
  static const navy = Color(0xFF102A43);
  static const navyLight = Color(0xFF243B53);

  // ── Surface / Containers ─────────────────────────────────────────────
  static const background = Color(0xFFF7F9FC);
  static const cardBorder = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);

  // ── Status ───────────────────────────────────────────────────────────
  static const available = Color(0xFF059669);
  static const soldOut = Color(0xFFE11D48);
  static const warning = Color(0xFFF59E0B);
  static const muted = Color(0xFF6B7C97);
}
