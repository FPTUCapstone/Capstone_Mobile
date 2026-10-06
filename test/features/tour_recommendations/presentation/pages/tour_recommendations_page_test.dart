import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/pages/tour_recommendations_page.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/tour_list_card.dart';

Widget _buildTestWidget({
  bool isDemoMode = false,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: TourRecommendationsPage(isDemoMode: isDemoMode),
    ),
  );
}

GoRouter _buildTourFlowRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.tourRecommendations,
        builder: (_, state) {
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          return TourRecommendationsPage(isDemoMode: isDemo);
        },
      ),
      GoRoute(
        path: AppRoutes.tourDetailPattern,
        builder: (_, state) {
          final tourId = state.pathParameters['tourId'] ?? '';
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          final summary = state.extra is TourSummary
              ? state.extra as TourSummary
              : null;
          return TourDetailPage(
            tourId: tourId,
            initialSummary: summary,
            isDemoMode: isDemo,
          );
        },
      ),
    ],
  );
}

void main() {
  group('TourRecommendationsPage', () {
    testWidgets('production mode shows pending integration truthfully', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(isDemoMode: false));
      await tester.pumpAndSettle();

      expect(find.text('Gợi ý Tour dành cho bạn'), findsOneWidget);
      expect(find.text('Đề xuất cá nhân hoá (> 80% phù hợp)'), findsOneWidget);
      expect(
        find.text('Tính năng gợi ý tour đang được tích hợp'),
        findsOneWidget,
      );
      expect(find.text('Khám phá tất cả Tour'), findsOneWidget);
      expect(find.byType(TourListCard), findsNothing);
    });

    testWidgets(
      'demo mode displays recommendations with score >80% and pagination',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        expect(find.text('Gợi ý Tour dành cho bạn'), findsOneWidget);
        expect(find.byType(TourListCard), findsWidgets);
        expect(find.textContaining('phù hợp'), findsWidgets);

        // Scroll down to reveal pagination controls
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();

        final nextBtn = find.byKey(const Key('rec-next-page-button'));
        expect(nextBtn, findsOneWidget);

        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();

        final prevBtn = find.byKey(const Key('rec-prev-page-button'));
        expect(prevBtn, findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
      },
    );

    testWidgets(
      'demo continuity: tapping recommended tour navigates to /explore/tours/{id}?demo=true and renders full Demo TourDetailPage',
      (tester) async {
        final authCubit = AuthSessionCubit();
        addTearDown(authCubit.close);
        final router = _buildTourFlowRouter(
          initialLocation: '${AppRoutes.tourRecommendations}?demo=true',
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          BlocProvider<AuthSessionCubit>.value(
            value: authCubit,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Demo recommendation cards render
        expect(find.byType(TourListCard), findsWidgets);

        // Tap the first recommended tour card (rec-101)
        await tester.tap(find.byType(TourListCard).first);
        await tester.pumpAndSettle();

        // Verify pushed route URI preserves ?demo=true
        final detailUri = GoRouterState.of(
          tester.element(find.byType(TourDetailPage)),
        ).uri;
        expect(detailUri.toString(), '/explore/tours/rec-101?demo=true');
        expect(detailUri.queryParameters['demo'], 'true');

        // Verify UC-26 renders full Demo detail (TourDetailStatus.success) and NOT pendingIntegration
        expect(find.text('Chi tiết Tour'), findsOneWidget);
        expect(find.text('Lịch khởi hành có sẵn'), findsOneWidget);
        expect(find.text('Lịch trình chi tiết'), findsOneWidget);
        expect(find.text('Chính sách hoàn huỷ'), findsOneWidget);
        expect(find.text('Đánh giá từ du khách'), findsOneWidget);
        expect(find.text('Chi tiết tour đang kết nối máy chủ'), findsNothing);

        // Verify Back button returns to /traveler/tours/recommendations?demo=true
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(TourDetailPage), findsNothing);
        final recUri = GoRouterState.of(
          tester.element(find.byType(TourRecommendationsPage)),
        ).uri;
        expect(recUri.toString(), '${AppRoutes.tourRecommendations}?demo=true');
        expect(find.text('Gợi ý Tour dành cho bạn'), findsOneWidget);
        expect(find.byType(TourListCard), findsWidgets);
      },
    );

    testWidgets(
      'production navigation: AppRoutes.tourDetail without demo keeps clean URL and renders pending integration',
      (tester) async {
        expect(AppRoutes.tourDetail('rec-101'), '/explore/tours/rec-101');
        expect(
          AppRoutes.tourDetail('rec-101', demo: false),
          '/explore/tours/rec-101',
        );
        expect(
          AppRoutes.tourDetail('rec-101', demo: true),
          '/explore/tours/rec-101?demo=true',
        );

        final authCubit = AuthSessionCubit();
        addTearDown(authCubit.close);
        final router = _buildTourFlowRouter(
          initialLocation: AppRoutes.tourRecommendations,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          BlocProvider<AuthSessionCubit>.value(
            value: authCubit,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Production recommendations screen shows pending integration truthfully
        expect(
          find.text('Tính năng gợi ý tour đang được tích hợp'),
          findsOneWidget,
        );

        // Navigate via production route helper (demo: false)
        unawaited(router.push(AppRoutes.tourDetail('rec-101')));
        await tester.pumpAndSettle();

        final prodDetailUri = GoRouterState.of(
          tester.element(find.byType(TourDetailPage)),
        ).uri;
        expect(prodDetailUri.toString(), '/explore/tours/rec-101');
        expect(prodDetailUri.queryParameters.containsKey('demo'), isFalse);

        // Production Tour Detail remains truthful: pending integration, no Demo data leaks
        expect(find.text('Chi tiết tour đang kết nối máy chủ'), findsOneWidget);
        expect(find.text('Lịch khởi hành có sẵn'), findsNothing);
        expect(find.text('Lịch trình chi tiết'), findsNothing);
      },
    );

    testWidgets('demo mode simulation switches to MSG28 no preferences state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
      await tester.pumpAndSettle();

      // Tap demo chip for MSG28
      final chip = find.text('Chưa có sở thích (MSG28)');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Chưa thiết lập sở thích'), findsOneWidget);
      expect(find.text(TourRecommendationsState.msg28), findsOneWidget);
      expect(find.text('Thiết lập sở thích du lịch'), findsOneWidget);
    });

    testWidgets('demo mode simulation switches to MSG64 no matches state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
      await tester.pumpAndSettle();

      final chip = find.text('Không khớp >80% (MSG64)');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Không có tour đạt mức phù hợp > 80%'), findsOneWidget);
      expect(find.text(TourRecommendationsState.msg64), findsOneWidget);
    });

    testWidgets('demo mode simulation switches to MSG127 error state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
      await tester.pumpAndSettle();

      final chip = find.text('Lỗi kết nối (MSG127)');
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải gợi ý tour'), findsOneWidget);
      expect(find.text(TourRecommendationsState.msg127), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    group('Responsive and accessibility checks', () {
      final viewports = <String, Size>{
        'compact 360x640': const Size(360, 640),
        'standard 390x844': const Size(390, 844),
        'large 412x915': const Size(412, 915),
      };

      for (final entry in viewports.entries) {
        testWidgets('renders cleanly on ${entry.key}', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Gợi ý Tour dành cho bạn'), findsOneWidget);
        });
      }

      testWidgets('renders without overflow at 200% font scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildTestWidget(isDemoMode: true, textScaleFactor: 2.0),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Gợi ý Tour dành cho bạn'), findsOneWidget);
      });
    });
  });
}
