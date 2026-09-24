import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi_search_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_itinerary_page.dart';

void main() {
  Widget buildPage() => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => CreateItineraryCubit(repository: _ItineraryRepository()),
      ),
      BlocProvider(
        create: (_) => PoiSearchCubit(
          locationService: _LocationService(),
          repository: _PoiRepository(),
        ),
      ),
    ],
    child: const MaterialApp(home: CreateItineraryPage()),
  );

  testWidgets('offers GPS and POI selection instead of coordinate entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('Choose a starting place'), findsOneWidget);
    expect(find.textContaining('latitude', findRichText: true), findsNothing);
    expect(find.textContaining('longitude', findRichText: true), findsNothing);

    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();

    expect(find.text('Current location'), findsOneWidget);
  });

  testWidgets('does not show Public transit as a transport option', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // Scroll until the settings card is visible by looking for 'Plan details'.
    await tester.scrollUntilVisible(
      find.text('How are you travelling?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // 'Public transit' must never appear in the transport dropdown.
    expect(find.text('Public transit'), findsNothing);
    // At least one supported mode label must be visible (current selection).
    expect(find.text('Motorbike'), findsOneWidget);
  });

  testWidgets('shows search radius slider and optional budget field', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Search radius'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Search radius'), findsOneWidget);
    expect(find.text('Budget (VND, optional)'), findsOneWidget);
  });

  testWidgets('generate button is always visible as the footer', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // The AppButton footer is inside the ListView in AppPageScaffold, so
    // scroll down to reach it.
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Generate itinerary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Generate itinerary'),
      findsOneWidget,
    );
  });

  testWidgets('rejects a non-positive budget instead of omitting it', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Budget (VND, optional)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    expect(
      find.text('Enter a positive budget or leave this field blank.'),
      findsOneWidget,
    );
  });
}

final class _ItineraryRepository implements ItineraryRepository {
  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

final class _LocationService implements DeviceLocationService {
  @override
  Future<DeviceLocation> getCurrentLocation() async =>
      const DeviceLocation(latitude: 16.0, longitude: 108.2);
}

final class _PoiRepository implements PointOfInterestRepository {
  @override
  Future<SelectablePoiSearchResult> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
    int page = 1,
    int pageSize = 50,
  }) async => const SelectablePoiSearchResult(items: [], totalCount: 0);
}
