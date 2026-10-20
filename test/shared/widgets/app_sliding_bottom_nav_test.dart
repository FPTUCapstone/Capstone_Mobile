import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';

void main() {
  const testDestinations = [
    AppNavDestination(
      label: 'Trang chủ',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavDestination(
      label: 'Khám phá',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
    ),
    AppNavDestination(
      label: 'Tour',
      icon: Icons.tour_outlined,
      selectedIcon: Icons.tour,
      badge: 'HOT',
    ),
    AppNavDestination(
      label: 'Tài khoản',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  testWidgets('renders all destinations and labels', (tester) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppSlidingBottomNav(
            selectedIndex: selected,
            onDestinationSelected: (index) => selected = index,
            destinations: testDestinations,
          ),
        ),
      ),
    );

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Tour'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('HOT'), findsOneWidget);

    // Initial selected tab has filled icon
    expect(find.byIcon(Icons.home), findsOneWidget);
    // Other tabs have outlined icons
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tour_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('tapping a tab invokes onDestinationSelected', (tester) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppSlidingBottomNav(
                selectedIndex: selected,
                onDestinationSelected: (index) {
                  setState(() => selected = index);
                },
                destinations: testDestinations,
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Khám phá'));
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(find.byIcon(Icons.explore), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('sliding highlight animates cleanly between tabs', (
    tester,
  ) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppSlidingBottomNav(
                selectedIndex: selected,
                onDestinationSelected: (index) {
                  setState(() => selected = index);
                },
                destinations: testDestinations,
              ),
            );
          },
        ),
      ),
    );

    // Capsule container is rendered with rounded pill styling by default
    final capsuleFinder = find.descendant(
      of: find.byType(AnimatedPositioned),
      matching: find.byType(Container),
    );
    expect(capsuleFinder, findsOneWidget);
    final initialLeft = tester.getRect(capsuleFinder).left;

    // Tap last tab
    await tester.tap(find.text('Tài khoản'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 80)); // Mid-flight animation

    final midLeft = tester.getRect(capsuleFinder).left;
    expect(midLeft, greaterThan(initialLeft));

    await tester.pumpAndSettle(); // End animation

    final endLeft = tester.getRect(capsuleFinder).left;
    expect(endLeft, greaterThan(midLeft));
    expect(selected, 3);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('handles rapid switching across multiple tabs smoothly', (
    tester,
  ) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppSlidingBottomNav(
                selectedIndex: selected,
                onDestinationSelected: (index) {
                  setState(() => selected = index);
                },
                destinations: testDestinations,
              ),
            );
          },
        ),
      ),
    );

    // Rapidly tap through all tabs
    await tester.tap(find.text('Khám phá'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Tour'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();

    expect(selected, 3);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('disables animation when MediaQuery.disableAnimations is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            bottomNavigationBar: AppSlidingBottomNav(
              selectedIndex: 2,
              onDestinationSelected: (_) {},
              destinations: testDestinations,
            ),
          ),
        ),
      ),
    );

    final pos = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    expect(pos.duration, Duration.zero);
  });

  testWidgets(
    'uses circular ink response without rectangular block by default',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppSlidingBottomNav(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: testDestinations,
            ),
          ),
        ),
      );

      final inkResponses = tester
          .widgetList<InkResponse>(find.byType(InkResponse))
          .toList();
      expect(inkResponses.length, testDestinations.length);

      for (final ink in inkResponses) {
        expect(ink.highlightShape, BoxShape.circle);
        expect(ink.containedInkWell, isFalse);
        expect(ink.radius, 28);
      }
    },
  );
}
