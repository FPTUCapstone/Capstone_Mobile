import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

Widget _themed(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    themeAnimationDuration: Duration.zero,
    home: Scaffold(body: child),
  );
}

void main() {
  group(
    'Shared Coastal Heritage Primitives — Light & Dark Token Compliance',
    () {
      testWidgets(
        'AppShimmer & Skeleton widgets default to TripMateColors shimmer tokens',
        (tester) async {
          await tester.pumpWidget(
            _themed(
              AppTheme.light,
              const AppShimmer(
                child: Column(
                  children: [
                    SkeletonBox(width: 80, height: 20),
                    SkeletonText(width: 100),
                    SkeletonCircle(size: 32),
                  ],
                ),
              ),
            ),
          );

          final lightBox = tester.widget<Container>(
            find.descendant(
              of: find.byType(SkeletonBox),
              matching: find.byType(Container),
            ),
          );
          expect(
            (lightBox.decoration! as BoxDecoration).color,
            TripMateColors.light.shimmerBase,
          );

          await tester.pumpWidget(
            _themed(
              AppTheme.dark,
              const AppShimmer(
                child: Column(
                  children: [
                    SkeletonBox(width: 80, height: 20),
                    SkeletonText(width: 100),
                    SkeletonCircle(size: 32),
                  ],
                ),
              ),
            ),
          );

          final darkBox = tester.widget<Container>(
            find.descendant(
              of: find.byType(SkeletonBox),
              matching: find.byType(Container),
            ),
          );
          expect(
            (darkBox.decoration! as BoxDecoration).color,
            TripMateColors.dark.shimmerBase,
          );
        },
      );

      testWidgets('AppAlert resolves semantic container colors from tmColors', (
        tester,
      ) async {
        await tester.pumpWidget(
          _themed(
            AppTheme.dark,
            const AppAlert(
              title: 'Notice',
              message: 'Saved cleanly',
              type: AppAlertType.success,
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(AppAlert),
            matching: find.byType(Container),
          ),
        );
        expect(
          (container.decoration! as BoxDecoration).color,
          TripMateColors.dark.successContainer,
        );
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.check_circle_outline),
        );
        expect(icon.color, TripMateColors.dark.success);
      });

      testWidgets('StatusBadge resolves Light & Dark semantic containers', (
        tester,
      ) async {
        await tester.pumpWidget(
          _themed(
            AppTheme.dark,
            const StatusBadge(label: 'Draft', type: StatusBadgeType.neutral),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(StatusBadge),
            matching: find.byType(Container),
          ),
        );
        expect(
          (container.decoration! as BoxDecoration).color,
          TripMateColors.dark.surfaceElevated,
        );
        final label = tester.widget<Text>(find.text('DRAFT'));
        expect(label.style?.color, TripMateColors.dark.textSecondary);
      });

      testWidgets('AppEmptyState resolves tmColors in Dark theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          _themed(
            AppTheme.dark,
            const AppEmptyState(
              title: 'No itineraries',
              message: 'Create your first Central Vietnam trip.',
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
        expect(icon.color, TripMateColors.dark.brandTeal);
        final title = tester.widget<Text>(find.text('No itineraries'));
        expect(title.style?.color, TripMateColors.dark.textPrimary);
      });

      testWidgets('ErrorView renders Coastal error badge, title, and retry', (
        tester,
      ) async {
        var retried = false;
        await tester.pumpWidget(
          _themed(
            AppTheme.dark,
            ErrorView(
              title: 'Unable to load',
              message: 'Network timeout occurred.',
              retryLabel: 'Retry',
              onRetry: () => retried = true,
            ),
          ),
        );

        expect(find.text('Unable to load'), findsOneWidget);
        expect(find.text('Network timeout occurred.'), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
        expect(icon.color, TripMateColors.dark.error);

        await tester.tap(find.text('Retry'));
        expect(retried, isTrue);
      });

      testWidgets('AppButton spinner uses textOnBrand in Dark theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          _themed(
            AppTheme.dark,
            AppButton(label: 'Continue', onPressed: () {}, isLoading: true),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.color, TripMateColors.dark.textOnBrand);
      });

      testWidgets('AppSlidingBottomNav adapts to Dark tmColors by default', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              bottomNavigationBar: AppSlidingBottomNav(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                destinations: const [
                  AppNavDestination(
                    label: 'Home',
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                  ),
                  AppNavDestination(
                    label: 'Profile',
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                  ),
                ],
              ),
            ),
          ),
        );

        final outer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AppSlidingBottomNav),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = outer.decoration! as BoxDecoration;
        expect(decoration.color, TripMateColors.dark.surfaceCard);
        expect(
          (decoration.border! as Border).top.color,
          TripMateColors.dark.borderSubtle,
        );
      });

      testWidgets(
        'AppPageScaffold supports subtitle, bottomBar, and pull-to-refresh',
        (tester) async {
          var refreshed = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: AppPageScaffold(
                title: 'Account Settings',
                subtitle: 'Manage preferences',
                onRefresh: () async => refreshed = true,
                bottomBar: const SizedBox(
                  key: Key('scaffold-bottom-bar'),
                  height: 48,
                  child: Text('Save changes'),
                ),
                content: const [Text('Body content')],
              ),
            ),
          );

          expect(find.text('Account Settings'), findsOneWidget);
          expect(find.text('Manage preferences'), findsOneWidget);
          expect(find.byKey(const Key('scaffold-bottom-bar')), findsOneWidget);
          expect(find.byType(RefreshIndicator), findsOneWidget);

          await tester.drag(find.text('Body content'), const Offset(0, 300));
          await tester.pumpAndSettle();
          expect(refreshed, isTrue);
        },
      );
    },
  );
}
