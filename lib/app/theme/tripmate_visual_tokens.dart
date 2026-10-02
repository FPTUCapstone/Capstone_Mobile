import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

/// Stitch-derived visual roles for the TripMate product screens (teal/navy).
///
/// The global [AppTheme] is intentionally left unchanged. Screens that have
/// been aligned with their Stitch design opt in through [TripMateVisualTheme];
/// every other screen keeps the existing theme until a global token migration.
abstract final class TripMateVisualTokens {
  static const teal = Color(0xFF006B5F);
  static const tealHover = Color(0xFF00544B);
  static const tealLight = Color(0xFFE6F4F2);
  static const navy = Color(0xFF102A43);
  static const navyDeep = Color(0xFF00152A);
  static const coral = Color(0xFFFF7043);
  static const coralLight = Color(0xFFFFF0EC);
  static const coralBorder = Color(0xFFFFCCBC);
  static const pageBackground = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const fieldReadOnly = Color(0xFFF1F5F9);
  static const text = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);

  static const fieldRadius = 12.0;
  static const cardRadius = 16.0;
  static const fieldHeight = 48.0;

  static const cardShadow = [
    BoxShadow(color: Color(0x0F102A43), blurRadius: 12, offset: Offset(0, 2)),
  ];

  /// Applies the Stitch roles on top of [base] for one screen subtree.
  static ThemeData apply(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: teal,
      onPrimary: Colors.white,
      primaryContainer: tealLight,
      onPrimaryContainer: tealHover,
      secondary: navy,
      onSecondary: Colors.white,
      surface: pageBackground,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: card,
      surfaceContainerHigh: fieldReadOnly,
      outline: border,
      outlineVariant: border,
    );
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBackground,
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: navy),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: card,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: navy,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        shape: const Border(bottom: BorderSide(color: border)),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: field(border),
        enabledBorder: field(border),
        focusedBorder: field(teal, 1.6),
        errorBorder: field(base.colorScheme.error),
        focusedErrorBorder: field(base.colorScheme.error, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          // A disabled primary action keeps its brand identity, dimmed.
          disabledBackgroundColor: teal.withValues(alpha: 0.38),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: tealLight,
          selectedForegroundColor: tealHover,
          foregroundColor: muted,
          side: const BorderSide(color: border),
        ),
      ),
    );
  }
}

/// Scopes [TripMateVisualTokens] to [child] without touching the global theme.
class TripMateVisualTheme extends StatelessWidget {
  const TripMateVisualTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TripMateVisualTokens.apply(Theme.of(context)),
      child: child,
    );
  }
}
