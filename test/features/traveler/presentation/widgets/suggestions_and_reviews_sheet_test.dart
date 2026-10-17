import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/external_reviews_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_suggestions_sheet.dart';

import '../cubit/suggestions_and_reviews_cubit_test.dart';

void main() {
  const fits = ItinerarySuggestion(
    poiId: 501,
    name: 'Bún chả cá Bà Lữ',
    costKind: CostKind.averageSpend,
    estimatedCost: 45000,
    distanceFromPreviousMeters: 1200,
    detourMinutes: 12,
    openAtArrival: true,
    closesAt: '21:00',
    fitsItinerary: true,
    tripadvisor: TripadvisorRating(
      locationId: 1,
      rating: 4.5,
      reviewCount: 310,
      ratingImageUrl: 'https://static.tacdn.com/img/4.5.svg',
      url: 'https://www.tripadvisor.com/x',
    ),
  );
  const tooLate = ItinerarySuggestion(
    poiId: 502,
    name: 'Mì Quảng 1A',
    costKind: CostKind.averageSpend,
    estimatedCost: 40000,
    distanceFromPreviousMeters: 3400,
    detourMinutes: 30,
    openAtArrival: true,
    fitsItinerary: false,
    unfitReason: 'ExceedsEndTime',
    unfitPoiId: 502,
    overflowMinutes: 80,
  );
  const pushesStopLate = ItinerarySuggestion(
    poiId: 503,
    name: 'Bánh xèo Bà Dưỡng',
    fitsItinerary: false,
    openAtArrival: true,
    unfitReason: 'ClosedAtArrival',
    unfitPoiId: 7,
    closesAt: '17:00',
  );

  Future<ItinerarySuggestion?> openSheet(
    WidgetTester tester,
    ItinerarySuggestions result,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ItinerarySuggestion? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showItinerarySuggestionsSheet(
                  context,
                  repository: FakeSuggestionRepository(result),
                  reviewRepository: FakeReviewRepository(reviewsFixture()),
                  itineraryId: 10,
                  kind: result.kind,
                  itemId: 70,
                  stopName: (poiId) => poiId == 7 ? 'Bảo tàng Chăm' : null,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('shows price, detour, closing time and Tripadvisor rating', (
    tester,
  ) async {
    await openSheet(
      tester,
      const ItinerarySuggestions(
        itineraryId: 10,
        kind: SuggestionKind.food,
        searchRadiusKm: 15,
        items: [fits],
      ),
    );

    expect(find.text('Thêm quán ăn'), findsOneWidget);
    expect(find.text('Mức chi tiêu dự kiến: 45.000 VNĐ/người'), findsOneWidget);
    expect(find.text('1,2 km · dài thêm 12 phút'), findsOneWidget);
    expect(find.text('Đóng cửa lúc 21:00'), findsOneWidget);
    expect(find.text('4,5/5 · 310 đánh giá'), findsOneWidget);
    // Plain text only: no Tripadvisor rating image, no self-drawn stars.
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('a Tripadvisor place without a rating shows only the count', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TripadvisorRatingRow(reviewCount: 717)),
      ),
    );

    expect(find.text('717 đánh giá'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the Tripadvisor rating is read out as plain attribution', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openSheet(
      tester,
      const ItinerarySuggestions(
        itineraryId: 10,
        kind: SuggestionKind.food,
        searchRadiusKm: 15,
        items: [fits],
      ),
    );

    final attribution = find.bySemanticsLabel('4,5/5 · 310 đánh giá');
    expect(attribution, findsOneWidget);
    // Nothing leaves TripMate for Tripadvisor: not a link, no tap target.
    expect(
      tester.getSemantics(attribution),
      isSemantics(
        label: '4,5/5 · 310 đánh giá',
        isLink: false,
        hasTapAction: false,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(TripadvisorRatingRow),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('"Xem đánh giá" shows unless Tripadvisor has no recent reviews', (
    tester,
  ) async {
    ItinerarySuggestion place(int poiId, String name, bool? hasRecent) =>
        ItinerarySuggestion(
          poiId: poiId,
          name: name,
          fitsItinerary: true,
          openAtArrival: true,
          tripadvisor: TripadvisorRating(
            locationId: poiId,
            rating: 4,
            reviewCount: 19,
            hasRecentReviews: hasRecent,
          ),
        );
    await openSheet(
      tester,
      ItinerarySuggestions(
        itineraryId: 10,
        kind: SuggestionKind.food,
        searchRadiusKm: 15,
        items: [
          place(1, 'Has recent', true),
          place(2, 'Nothing recent', false),
          place(3, 'Not checked', null),
        ],
      ),
    );

    Finder reviewsButtonIn(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(InkWell)),
      matching: find.text('Xem đánh giá'),
    );
    expect(reviewsButtonIn('Has recent'), findsOneWidget);
    expect(reviewsButtonIn('Nothing recent'), findsNothing);
    expect(reviewsButtonIn('Not checked'), findsOneWidget);
    // The rating and count stay visible for every place.
    expect(find.text('4/5 · 19 đánh giá'), findsNWidgets(3));
  });

  testWidgets('places that do not fit are greyed with the reason', (
    tester,
  ) async {
    await openSheet(
      tester,
      const ItinerarySuggestions(
        itineraryId: 10,
        kind: SuggestionKind.replace,
        searchRadiusKm: 15,
        items: [tooLate, pushesStopLate],
      ),
    );

    final semantics = tester.ensureSemantics();
    expect(find.text('Thay địa điểm'), findsOneWidget);
    expect(find.text('Vượt giờ kết thúc 1 giờ 20 phút'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^Mì Quảng 1A'))),
      isSemantics(
        label: 'Mì Quảng 1A. Không chọn được: Vượt giờ kết thúc 1 giờ 20 phút',
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
    expect(
      find.text('Bảo tàng Chăm: đã đóng cửa khi đến nơi (đóng cửa lúc 17:00)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mì Quảng 1A'));
    await tester.pumpAndSettle();
    // Not selectable: the sheet stays open.
    expect(find.text('Thay địa điểm'), findsOneWidget);
  });

  testWidgets('choosing a place that fits returns it', (tester) async {
    ItinerarySuggestion? chosen;
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await showItinerarySuggestionsSheet(
                context,
                repository: FakeSuggestionRepository(
                  const ItinerarySuggestions(
                    itineraryId: 10,
                    kind: SuggestionKind.food,
                    searchRadiusKm: 15,
                    items: [fits],
                  ),
                ),
                itineraryId: 10,
                kind: SuggestionKind.food,
                itemId: 70,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bún chả cá Bà Lữ'));
    await tester.pumpAndSettle();

    expect(chosen, fits);
  });

  testWidgets('no place found names the radius', (tester) async {
    await openSheet(
      tester,
      const ItinerarySuggestions(
        itineraryId: 10,
        kind: SuggestionKind.food,
        searchRadiusKm: 15,
        items: [],
      ),
    );

    expect(find.text('Không có điểm phù hợp trong 15 km'), findsOneWidget);
    expect(find.textContaining('Mở rộng bán kính'), findsOneWidget);
  });

  group('reviews sheet', () {
    Future<void> openReviews(
      WidgetTester tester,
      FakeReviewRepository repository,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExternalReviewsSheet(
                context,
                repository: repository,
                poiId: 501,
                poiName: 'Bún chả cá Bà Lữ',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Tripadvisor attribution and translates on demand', (
      tester,
    ) async {
      final repository = FakeReviewRepository(reviewsFixture());
      await openReviews(tester, repository);

      expect(find.text('4,5/5 · 310 đánh giá'), findsOneWidget);
      // Each review's rating is text too: no Tripadvisor image anywhere.
      expect(find.text('5/5'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      // No link out of TripMate to Tripadvisor.
      expect(find.text('Xem trên Tripadvisor'), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TripadvisorRatingRow),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(find.text('Loved it'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);

      await tester.tap(find.text('Dịch sang tiếng Việt'));
      await tester.pumpAndSettle();

      expect(find.text('Rất ngon'), findsOneWidget);
      expect(find.text('Loved it'), findsNothing);
      expect(find.text('Bản dịch tự động · Xem bản gốc'), findsOneWidget);

      await tester.tap(find.text('Bản dịch tự động · Xem bản gốc'));
      await tester.pumpAndSettle();
      expect(find.text('Loved it'), findsOneWidget);
    });

    testWidgets('no translate button when translation is off', (tester) async {
      await openReviews(
        tester,
        FakeReviewRepository(reviewsFixture(translationAvailable: false)),
      );

      expect(find.text('Loved it'), findsOneWidget);
      expect(find.text('Dịch sang tiếng Việt'), findsNothing);
    });

    testWidgets('no recent reviews shows the rating and a neutral note', (
      tester,
    ) async {
      await openReviews(
        tester,
        FakeReviewRepository(reviewsFixture(reviews: const [])),
      );

      expect(find.text('4,5/5 · 310 đánh giá'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        find.text('Chưa có đánh giá gần đây để hiển thị.'),
        findsOneWidget,
      );
      expect(find.text('Chưa có đánh giá gần đây.'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('a place without Tripadvisor shows no rating block', (
      tester,
    ) async {
      await openReviews(
        tester,
        FakeReviewRepository(reviewsFixture(source: null)),
      );

      expect(find.textContaining('· 310 đánh giá'), findsNothing);
      expect(find.byType(TripadvisorRatingRow), findsNothing);
      expect(find.text('Loved it'), findsNothing);
      expect(find.text('Chưa có đánh giá cho địa điểm này.'), findsOneWidget);
    });
  });
}
