import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const fontFamily = 'Roboto';

  static TextTheme textTheme(Color foreground) {
    return TextTheme(
      displaySmall: TextStyle(
        color: foreground,
        fontSize: 36,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: foreground,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: foreground,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: foreground, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: foreground, fontSize: 14, height: 1.4),
      labelLarge: TextStyle(
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ).apply(fontFamily: fontFamily);
  }
}
