import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';

void main() {
  group('AppShimmer Widget Tests', () {
    testWidgets('renders child content correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppShimmer(child: Text('Shimmering content'))),
        ),
      );

      expect(find.text('Shimmering content'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('respects disableAnimations accessibility setting', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: AppShimmer(child: Text('Static content'))),
          ),
        ),
      );

      expect(find.text('Static content'), findsOneWidget);
      // When animations are disabled, ShaderMask is not built
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('Skeleton components render expected dimensions', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SkeletonBox(width: 120, height: 80, borderRadius: 12),
                SkeletonText(width: 200, height: 16),
                SkeletonCircle(size: 48),
              ],
            ),
          ),
        ),
      );

      final boxFinder = find.byType(SkeletonBox);
      final textFinder = find.byType(SkeletonText);
      final circleFinder = find.byType(SkeletonCircle);

      expect(boxFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);
      expect(circleFinder, findsOneWidget);

      final boxSize = tester.getSize(boxFinder);
      expect(boxSize.width, 120);
      expect(boxSize.height, 80);

      final textSize = tester.getSize(textFinder);
      expect(textSize.width, 200);
      expect(textSize.height, 16);

      final circleSize = tester.getSize(circleFinder);
      expect(circleSize.width, 48);
      expect(circleSize.height, 48);
    });
  });
}
