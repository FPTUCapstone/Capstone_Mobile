import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

final class _DummyThemeExtension extends ThemeExtension<TripMateColors> {
  const _DummyThemeExtension();

  @override
  ThemeExtension<TripMateColors> copyWith() => this;

  @override
  ThemeExtension<TripMateColors> lerp(
    covariant ThemeExtension<TripMateColors>? other,
    double t,
  ) => this;
}

double _relativeLuminanceChannel(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) {
  final r = _relativeLuminanceChannel(color.r);
  final g = _relativeLuminanceChannel(color.g);
  final b = _relativeLuminanceChannel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color foreground, Color background) {
  final l1 = _luminance(foreground);
  final l2 = _luminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('PR 1 Theme Tokens, Typography & Verified Assets', () {
    test('Light and Dark TripMateColors pass WCAG AA contrast rules', () {
      const light = TripMateColors.light;
      const dark = TripMateColors.dark;

      // Light mode pairs
      expect(_contrastRatio(light.textPrimary, light.canvas), greaterThan(4.5));
      expect(
        _contrastRatio(light.textPrimary, light.surfaceCard),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.textSecondary, light.canvas),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.coralAccessibleText, light.surfaceCard),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.coralAccessibleText, light.canvas),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.textOnCoralBadge, light.brandCoral),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.textOnBrand, light.actionPrimary),
        greaterThan(4.5),
      );

      // Dark mode pairs
      expect(_contrastRatio(dark.textPrimary, dark.canvas), greaterThan(4.5));
      expect(
        _contrastRatio(dark.textPrimary, dark.surfaceCard),
        greaterThan(4.5),
      );
      expect(_contrastRatio(dark.textSecondary, dark.canvas), greaterThan(4.5));
      expect(
        _contrastRatio(dark.coralAccessibleText, dark.surfaceCard),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(dark.textOnBrand, dark.actionPrimary),
        greaterThan(4.5),
      );

      // ThemeExtension copyWith + null-safe lerp (CR-01)
      expect(identical(light.lerp(null, 0.5), light), isTrue);
      expect(
        identical(light.lerp(const _DummyThemeExtension(), 0.5), light),
        isTrue,
      );
      final atZero = light.lerp(dark, 0.0);
      expect(atZero.canvas, light.canvas);
      expect(atZero.brandNavy, light.brandNavy);
      expect(atZero.isDark, isFalse);

      final atOne = light.lerp(dark, 1.0);
      expect(atOne.canvas, dark.canvas);
      expect(atOne.brandTeal, dark.brandTeal);
      expect(atOne.isDark, isTrue);

      final lerped = light.lerp(dark, 0.5);
      expect(lerped.canvas, Color.lerp(light.canvas, dark.canvas, 0.5));
      expect(
        lerped.coralAccessibleText,
        Color.lerp(light.coralAccessibleText, dark.coralAccessibleText, 0.5),
      );
      expect(lerped.isDark, isTrue);
      expect(light.lerp(dark, 0.49).isDark, isFalse);
      expect(light.copyWith(brandNavy: Colors.black).brandNavy, Colors.black);
      expect(TripMateRadius.pill, 999.0);
    });

    test(
      'AppTheme.light and AppTheme.dark expose isolated surface/input tokens',
      () {
        final lightTheme = AppTheme.light;
        final darkTheme = AppTheme.dark;

        expect(lightTheme.brightness, Brightness.light);
        expect(darkTheme.brightness, Brightness.dark);

        // CR-02: Light and Dark ColorScheme tertiary/onTertiary WCAG AA contrast
        expect(
          _contrastRatio(
            lightTheme.colorScheme.onTertiary,
            lightTheme.colorScheme.tertiary,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(
            darkTheme.colorScheme.onTertiary,
            darkTheme.colorScheme.tertiary,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          darkTheme.colorScheme.onTertiary,
          TripMateColors.dark.textOnCoralBadge,
        );

        expect(lightTheme.scaffoldBackgroundColor, TripMateColors.light.canvas);
        expect(darkTheme.scaffoldBackgroundColor, TripMateColors.dark.canvas);

        expect(
          lightTheme.appBarTheme.backgroundColor,
          TripMateColors.light.surfaceCard,
        );
        expect(
          darkTheme.appBarTheme.backgroundColor,
          TripMateColors.dark.surfaceCard,
        );

        expect(
          lightTheme.navigationBarTheme.backgroundColor,
          TripMateColors.light.surfaceCard,
        );
        expect(
          darkTheme.navigationBarTheme.backgroundColor,
          TripMateColors.dark.surfaceCard,
        );

        expect(
          lightTheme.inputDecorationTheme.fillColor,
          TripMateColors.light.surfaceCard,
        );
        expect(
          darkTheme.inputDecorationTheme.fillColor,
          TripMateColors.dark.surfaceCard,
        );

        expect(
          lightTheme.extension<TripMateColors>(),
          equals(TripMateColors.light),
        );
        expect(
          darkTheme.extension<TripMateColors>(),
          equals(TripMateColors.dark),
        );

        expect(AppTypography.displayFont, 'BricolageGrotesque');
        expect(AppTypography.uiFont, 'Manrope');
        expect(
          lightTheme.textTheme.displaySmall?.fontFamily,
          'BricolageGrotesque',
        );
        expect(
          lightTheme.textTheme.headlineMedium?.fontFamily,
          'BricolageGrotesque',
        );
        expect(lightTheme.textTheme.bodyMedium?.fontFamily, 'Manrope');
        expect(
          AppTypography.price(TripMateColors.light.textPrimary).fontFeatures,
          isNotEmpty,
        );
      },
    );

    testWidgets(
      'AppTheme.light and AppTheme.dark separately resolve tmColors and button contrast',
      (tester) async {
        late TripMateColors lightCtxColors;
        late TripMateColors darkCtxColors;
        late Color lightOutlinedFg;
        late Color darkOutlinedFg;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) {
                lightCtxColors = context.tmColors;
                lightOutlinedFg =
                    Theme.of(
                      context,
                    ).outlinedButtonTheme.style?.foregroundColor?.resolve({}) ??
                    Colors.transparent;
                return const Scaffold(body: Text('Light check'));
              },
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            home: Builder(
              builder: (context) {
                darkCtxColors = context.tmColors;
                darkOutlinedFg =
                    Theme.of(
                      context,
                    ).outlinedButtonTheme.style?.foregroundColor?.resolve({}) ??
                    Colors.transparent;
                return const Scaffold(body: Text('Dark check'));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(lightCtxColors.isDark, isFalse);
        expect(darkCtxColors.isDark, isTrue);
        expect(
          _contrastRatio(lightOutlinedFg, lightCtxColors.canvas),
          greaterThan(4.5),
        );
        expect(
          _contrastRatio(darkOutlinedFg, darkCtxColors.canvas),
          greaterThan(4.5),
        );
      },
    );

    test(
      'All 9 Wikimedia destination JPEGs, attribution manifest, and OFL fonts are bundled cleanly',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        const destinations = [
          'assets/images/destinations/bana_golden_bridge.jpg',
          'assets/images/destinations/danang_dragon_bridge.jpg',
          'assets/images/destinations/danang_dragon_night.jpg',
          'assets/images/destinations/hoian_ancient_town.jpg',
          'assets/images/destinations/hoian_lantern_night.jpg',
          'assets/images/destinations/hue_ngo_mon.jpg',
          'assets/images/destinations/marble_mountains.jpg',
          'assets/images/destinations/my_khe_beach.jpg',
          'assets/images/destinations/son_tra_pagoda.jpg',
        ];

        for (final path in destinations) {
          final bytes = await rootBundle.load(path);
          expect(
            bytes.lengthInBytes,
            greaterThan(50000),
            reason: '$path missing',
          );
          expect(bytes.getUint8(0), 0xFF);
          expect(bytes.getUint8(1), 0xD8);
        }

        final attribution = await rootBundle.loadString(
          'assets/images/destinations/ATTRIBUTION.md',
        );
        expect(attribution, contains('DvTor8303'));
        expect(attribution, contains('CC0 1.0'));
        expect(attribution, contains('Person-with-No Name'));
        expect(attribution, contains('Steffen Schmitz'));
        expect(attribution, contains('Chainwit.'));
        expect(attribution, contains('CEphoto, Uwe Aranas'));

        const fontAssets = [
          'assets/fonts/BricolageGrotesque-Medium.ttf',
          'assets/fonts/BricolageGrotesque-SemiBold.ttf',
          'assets/fonts/BricolageGrotesque-Bold.ttf',
          'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
          'assets/fonts/BricolageGrotesque_OFL.txt',
          'assets/fonts/Manrope-Regular.ttf',
          'assets/fonts/Manrope-Medium.ttf',
          'assets/fonts/Manrope-SemiBold.ttf',
          'assets/fonts/Manrope-Bold.ttf',
          'assets/fonts/Manrope-ExtraBold.ttf',
          'assets/fonts/Manrope_OFL.txt',
        ];
        for (final font in fontAssets) {
          final data = await rootBundle.load(font);
          expect(
            data.lengthInBytes,
            greaterThan(1000),
            reason: '$font missing',
          );
        }
      },
    );
  });
}
