import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/pages/tour_recommendations_page.dart';
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
