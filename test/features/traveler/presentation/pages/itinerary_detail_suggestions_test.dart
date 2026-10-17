import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';

import '../cubit/suggestions_and_reviews_cubit_test.dart';
import 'itinerary_detail_edit_test.dart';

/// Review 2: item menu, lunch card, add / replace / remove, reviews.
void main() {
  DateTime vn(int hour, int minute) =>
      DateTime.utc(2026, 10, 18, hour - 7, minute);

  const noodle = ItinerarySuggestion(
    poiId: 501,
    name: 'Bún chả cá Bà Lữ',
    costKind: CostKind.averageSpend,
    estimatedCost: 45000,
    fitsItinerary: true,
    openAtArrival: true,
  );

  Future<(EditRepository, FakeSuggestionRepository)> pump(
    WidgetTester tester,
    ItineraryDetail detail, {
    ItinerarySuggestions? suggestions,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = EditRepository(detail);
    final suggestionRepository = FakeSuggestionRepository(
      suggestions ??
          const ItinerarySuggestions(
            itineraryId: 10,
            kind: SuggestionKind.food,
            searchRadiusKm: 15,
            items: [noodle],
          ),
    );
    final cubit = ItineraryDetailCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: ItineraryDetailPage(
            itineraryId: 10,
            suggestionRepository: suggestionRepository,
            reviewRepository: FakeReviewRepository(reviewsFixture()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repository, suggestionRepository);
  }

  /// Museum 08:00–10:00, beach 10:30–11:45, park 13:00–14:00; the trip runs
  /// until 15:00 and has no restaurant.
  ItineraryDetail lunchPlan() => editablePlan(
    validTo: vn(15, 0),
    items: [
      planItem(1, 'Cham Museum', vn(8, 0), stay: 120, isMandatory: true),
      planItem(2, 'My Khe Beach', vn(10, 30), travelMinutes: 20, stay: 75),
      planItem(3, 'Asia Park', vn(13, 0), travelMinutes: 15),
    ],
  );

  testWidgets('lunch card adds a restaurant after the stop nearest noon', (
    tester,
  ) async {
    final (repository, suggestions) = await pump(tester, lunchPlan());

    expect(find.text('🍜 Bữa trưa?'), findsOneWidget);
    await tester.tap(find.text('Chọn quán'));
    await tester.pumpAndSettle();

    expect(suggestions.requests.single, (10, SuggestionKind.food, 20));
    await tester.tap(find.text('Bún chả cá Bà Lữ'));
    await tester.pumpAndSettle();

    expect(repository.sentStops.single, const [
      ItineraryStop(poiId: 1),
      ItineraryStop(poiId: 2),
      ItineraryStop(poiId: 501),
      ItineraryStop(poiId: 3),
    ]);
  });

  testWidgets('no lunch card when a restaurant is planned', (tester) async {
    await pump(tester, editablePlan(validTo: vn(15, 0)));

    expect(find.text('🍜 Bữa trưa?'), findsNothing);
  });

  testWidgets('a restaurant can be added after the last stop', (tester) async {
    final (_, suggestions) = await pump(tester, lunchPlan());

    await tester.tap(find.text('Thêm quán ăn'));
    await tester.pumpAndSettle();

    expect(suggestions.requests.single, (10, SuggestionKind.food, 30));
  });

  testWidgets('removing a must-see stop asks first', (tester) async {
    final (repository, _) = await pump(tester, lunchPlan());

    await tester.tap(find.byTooltip('Tùy chọn cho Cham Museum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ khỏi lịch'));
    await tester.pumpAndSettle();

    expect(find.text('Bỏ điểm bắt buộc?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(repository.sentStops, isEmpty);

    await tester.tap(find.byTooltip('Tùy chọn cho Cham Museum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ khỏi lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ khỏi lịch'));
    await tester.pumpAndSettle();

    expect(repository.sentStops.single, const [
      ItineraryStop(poiId: 2),
      ItineraryStop(poiId: 3),
    ]);
  });

  testWidgets('replacing a stop uses same-category suggestions', (
    tester,
  ) async {
    final (repository, suggestions) = await pump(
      tester,
      lunchPlan(),
      suggestions: const ItinerarySuggestions(
        itineraryId: 10,
        kind: SuggestionKind.replace,
        searchRadiusKm: 15,
        items: [
          ItinerarySuggestion(
            poiId: 601,
            name: 'Son Tra Peninsula',
            fitsItinerary: true,
            openAtArrival: true,
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('Tùy chọn cho My Khe Beach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thay địa điểm'));
    await tester.pumpAndSettle();

    expect(suggestions.requests.single, (10, SuggestionKind.replace, 20));
    await tester.tap(find.text('Son Tra Peninsula'));
    await tester.pumpAndSettle();

    expect(repository.sentStops.single, const [
      ItineraryStop(poiId: 1),
      ItineraryStop(poiId: 601),
      ItineraryStop(poiId: 3),
    ]);
  });

  testWidgets('replacing a must-see stop asks first', (tester) async {
    final (_, suggestions) = await pump(tester, lunchPlan());

    await tester.tap(find.byTooltip('Tùy chọn cho Cham Museum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thay địa điểm'));
    await tester.pumpAndSettle();

    expect(find.text('Thay điểm bắt buộc?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(suggestions.requests, isEmpty);

    await tester.tap(find.byTooltip('Tùy chọn cho Cham Museum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thay địa điểm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thay địa điểm'));
    await tester.pumpAndSettle();

    expect(suggestions.requests.single, (10, SuggestionKind.replace, 10));
  });

  testWidgets('reviews open from the stop menu', (tester) async {
    await pump(tester, lunchPlan());

    await tester.tap(find.byTooltip('Tùy chọn cho Cham Museum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem đánh giá'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh giá · Cham Museum'), findsOneWidget);
    expect(find.text('Loved it'), findsOneWidget);
  });

  testWidgets('a group member can only read reviews', (tester) async {
    await pump(tester, editablePlan(canManage: false, validTo: vn(15, 0)));

    expect(find.text('Thêm quán ăn'), findsNothing);
    await tester.tap(find.byTooltip('Tùy chọn cho Cham Museum'));
    await tester.pumpAndSettle();

    expect(find.text('Xem đánh giá'), findsOneWidget);
    expect(find.text('Thay địa điểm'), findsNothing);
    expect(find.text('Bỏ khỏi lịch'), findsNothing);
  });

  testWidgets('regenerating warns that added restaurants are dropped', (
    tester,
  ) async {
    final (repository, _) = await pump(tester, editablePlan());

    await tester.tap(find.byTooltip('Tạo lại lịch trình'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo lại lịch trình?'), findsOneWidget);
    await tester.tap(find.text('Giữ lịch hiện tại'));
    await tester.pumpAndSettle();
    expect(repository.regenerateCalls, 0);

    await tester.tap(find.byTooltip('Tạo lại lịch trình'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo lại'));
    await tester.pumpAndSettle();
    expect(repository.regenerateCalls, 1);
  });
}
