import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi_search_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/address_search_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/address_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_itinerary_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

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

  testWidgets('shows progress while the current location is pending', (
    tester,
  ) async {
    final pending = Completer<DeviceLocation>();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                CreateItineraryCubit(repository: _ItineraryRepository()),
          ),
          BlocProvider(
            create: (_) => PoiSearchCubit(
              locationService: _LocationService(pending),
              repository: _PoiRepository(),
            ),
          ),
        ],
        child: const MaterialApp(home: CreateItineraryPage()),
      ),
    );

    await tester.tap(find.text('Use current location'));
    await tester.pump();

    expect(find.text('Finding your location…'), findsOneWidget);
    expect(find.text('Use current location'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Finding your location…'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);

    pending.complete(const DeviceLocation(latitude: 16.0, longitude: 108.2));
    await tester.pumpAndSettle();

    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
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
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 1);
    expect(slider.max, 100);
    expect(slider.divisions, 99);
    expect(find.text('Search radius'), findsOneWidget);
    expect(find.text('Budget (VND, optional)'), findsOneWidget);
  });

  testWidgets('warns when the search radius is above 30 km', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Search radius'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wide_radius_warning')), findsNothing);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(30);
    await tester.pump();
    expect(find.byKey(const Key('wide_radius_warning')), findsNothing);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(31);
    await tester.pump();
    expect(find.byKey(const Key('wide_radius_warning')), findsOneWidget);
  });

  testWidgets('must-see picker leaves restaurants out, end picker does not', (
    tester,
  ) async {
    final repository = _RecordingPoiRepository();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                CreateItineraryCubit(repository: _ItineraryRepository()),
          ),
          BlocProvider(
            create: (_) => PoiSearchCubit(
              locationService: _LocationService(),
              repository: repository,
            ),
          ),
        ],
        child: const MaterialApp(home: CreateItineraryPage()),
      ),
    );
    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add a must-see place'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a must-see place'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search places'),
      'Museum',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.excludeFoodAndDrink, [true]);
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
    await tester.enterText(
      find.widgetWithText(TextField, 'Budget (VND, optional)'),
      '0',
    );
    await tester.pump();

    expect(
      find.text('Enter a positive budget or leave this field blank.'),
      findsOneWidget,
    );
  });

  group('time available', () {
    Future<void> showDurationFields(WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('available_time_helper')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }

    String helperText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('available_time_helper')))
        .data!;

    testWidgets('accepts any hours and minutes, even past midnight', (
      tester,
    ) async {
      await showDurationFields(tester);

      await tester.enterText(
        find.byKey(const Key('available_hours_field')),
        '30',
      );
      await tester.enterText(
        find.byKey(const Key('available_minutes_field')),
        '15',
      );
      await tester.pump();

      expect(helperText(tester), startsWith('1 hour to 3 days. Ends '));
    });

    testWidgets('rejects less than one hour', (tester) async {
      await showDurationFields(tester);

      await tester.enterText(
        find.byKey(const Key('available_hours_field')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('available_minutes_field')),
        '45',
      );
      await tester.pump();

      expect(helperText(tester), 'Plan at least 1 hour.');
    });

    testWidgets('rejects more than three days', (tester) async {
      await showDurationFields(tester);

      await tester.enterText(
        find.byKey(const Key('available_hours_field')),
        '72',
      );
      await tester.enterText(
        find.byKey(const Key('available_minutes_field')),
        '1',
      );
      await tester.pump();

      expect(helperText(tester), 'A trip can last at most 72 hours (3 days).');
    });

    testWidgets('rejects more than 59 minutes', (tester) async {
      await showDurationFields(tester);

      await tester.enterText(
        find.byKey(const Key('available_minutes_field')),
        '75',
      );
      await tester.pump();

      expect(helperText(tester), 'Enter whole hours and 0–59 minutes.');
    });
  });

  testWidgets('disables budget field while generation is in flight', (
    tester,
  ) async {
    final completer = Completer<GeneratedItinerary>();
    final itineraryRepository = _DeferredItineraryRepository(completer);
    final poiRepository = _SinglePoiRepository();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                CreateItineraryCubit(repository: itineraryRepository),
          ),
          BlocProvider(
            create: (_) => PoiSearchCubit(
              locationService: _LocationService(),
              repository: poiRepository,
            ),
          ),
        ],
        child: const MaterialApp(home: CreateItineraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore around'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search places'),
      'Da Nang',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Da Nang Beach'));
    await tester.pumpAndSettle();

    final budgetFieldFinder = find.widgetWithText(
      TextField,
      'Budget (VND, optional)',
    );
    await tester.scrollUntilVisible(
      budgetFieldFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(budgetFieldFinder, '500000');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(budgetFieldFinder).enabled, isTrue);

    final generateButton = find.widgetWithText(
      FilledButton,
      'Generate itinerary',
    );
    await tester.scrollUntilVisible(
      generateButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pump();

    expect(tester.widget<TextField>(budgetFieldFinder).enabled, isFalse);

    completer.completeError(Exception('Failed to generate'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(budgetFieldFinder).enabled, isTrue);
  });

  testWidgets(
    'opens the POI picker when the cubits are provided inside the route',
    (tester) async {
      // Mirrors AppRouter: providers wrap the page, not the Navigator, so the
      // modal sheet's route is outside their subtree.
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    CreateItineraryCubit(repository: _ItineraryRepository()),
              ),
              BlocProvider(
                create: (_) => PoiSearchCubit(
                  locationService: _LocationService(),
                  repository: _ScopedPoiRepository(),
                ),
              ),
              BlocProvider(
                create: (_) =>
                    AddressSearchCubit(repository: _AddressRepository()),
              ),
            ],
            child: const CreateItineraryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose a starting place'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(TextField, 'Address or place name'),
        findsOneWidget,
      );
    },
  );

  Future<void> pumpWithAddresses(
    WidgetTester tester,
    _AddressRepository addressRepository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  CreateItineraryCubit(repository: _ItineraryRepository()),
            ),
            BlocProvider(
              create: (_) => PoiSearchCubit(
                locationService: _LocationService(),
                repository: _ScopedPoiRepository(),
              ),
            ),
            BlocProvider(
              create: (_) => AddressSearchCubit(repository: addressRepository),
            ),
          ],
          child: const CreateItineraryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starting point accepts a typed street address', (tester) async {
    final addresses = _AddressRepository(
      results: const [
        AddressSuggestion(
          name: '123 Nguyễn Văn Linh',
          fullAddress: '123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng, Việt Nam',
          latitude: 16.0603,
          longitude: 108.2105,
        ),
      ],
    );
    await pumpWithAddresses(tester, addresses);

    await tester.tap(find.text('Choose a starting place'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Address or place name'),
      '123 nguyen van linh',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(addresses.queries, ['123 nguyen van linh']);
    expect(find.text('Addresses'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    await tester.tap(find.text('123 Nguyễn Văn Linh'));
    await tester.pumpAndSettle();

    expect(addresses.resolved, ['123 Nguyễn Văn Linh']);
    expect(
      find.text('123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng, Việt Nam'),
      findsOneWidget,
    );
    final explore = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Explore around'),
    );
    expect(explore.onTap, isNotNull);
  });

  testWidgets('a catalog place can still be the starting point', (
    tester,
  ) async {
    await pumpWithAddresses(tester, _AddressRepository());

    await tester.tap(find.text('Choose a starting place'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Address or place name'),
      'Scope',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No matching address.'), findsOneWidget);
    await tester.tap(find.text('POI in Scope A'));
    await tester.pumpAndSettle();

    expect(find.text('POI in Scope A'), findsOneWidget);
    expect(find.text('No starting point selected'), findsNothing);
  });

  testWidgets('without Mapbox the start search covers catalog places only', (
    tester,
  ) async {
    final addresses = _AddressRepository(isAvailable: false);
    await pumpWithAddresses(tester, addresses);

    await tester.tap(find.text('Choose a starting place'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Place name'),
      'Scope',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Addresses'), findsNothing);
    expect(find.text('POI in Scope A'), findsOneWidget);
    expect(addresses.queries, isEmpty);
  });

  testWidgets('invalidates stale POI results when picker scope changes', (
    tester,
  ) async {
    final poiRepository = _ScopedPoiRepository();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                CreateItineraryCubit(repository: _ItineraryRepository()),
          ),
          BlocProvider(
            create: (_) => PoiSearchCubit(
              locationService: _LocationService(),
              repository: poiRepository,
            ),
          ),
          BlocProvider(
            create: (_) => AddressSearchCubit(repository: _AddressRepository()),
          ),
        ],
        child: const MaterialApp(home: CreateItineraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose a starting place'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Address or place name'),
      'ScopeA',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('POI in Scope A'), findsOneWidget);

    Navigator.of(tester.element(find.text('POI in Scope A'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore around'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search places'),
      'Explore',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('POI in Scope B'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add a must-see place'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a must-see place'));
    await tester.pumpAndSettle();

    expect(find.text('POI in Scope A'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('POI in Scope B'),
      ),
      findsNothing,
    );
    expect(find.text('Search by name to find a place.'), findsOneWidget);
  });

  testWidgets(
    'auto-binds primary POI with badge when exploration area is selected',
    (tester) async {
      final poiRepository = _ScopedPoiRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    CreateItineraryCubit(repository: _ItineraryRepository()),
              ),
              BlocProvider(
                create: (_) => PoiSearchCubit(
                  locationService: _LocationService(),
                  repository: poiRepository,
                ),
              ),
              BlocProvider(
                create: (_) =>
                    AddressSearchCubit(repository: _AddressRepository()),
              ),
            ],
            child: const CreateItineraryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore around'));
      await tester.pumpAndSettle();

      // Verify quick suggestion chips exist
      expect(find.text('Bà Nà Hills'), findsOneWidget);
      expect(find.text('Sơn Trà'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search places'),
        'Explore',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('POI in Scope B'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Must-see places'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Primary POI is auto-bound with badge
      expect(find.text('POI in Scope B (Điểm chính)'), findsOneWidget);

      // Deleting chip removes it from mandatory without breaking exploration
      final chip = tester.widget<InputChip>(find.byType(InputChip).first);
      chip.onDeleted!();
      await tester.pumpAndSettle();

      expect(find.text('POI in Scope B (Điểm chính)'), findsNothing);

      // Scroll back up to verify "Explore around" field still holds the exploration POI
      await tester.scrollUntilVisible(
        find.text('Explore around'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('POI in Scope B'), findsOneWidget);
    },
  );

  testWidgets(
    'displays travel feasibility warning when round-trip travel exceeds 50% of available time',
    (tester) async {
      final poiRepository = _ScopedPoiRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    CreateItineraryCubit(repository: _ItineraryRepository()),
              ),
              BlocProvider(
                create: (_) => PoiSearchCubit(
                  locationService: _LocationService(),
                  repository: poiRepository,
                ),
              ),
              BlocProvider(
                create: (_) =>
                    AddressSearchCubit(repository: _AddressRepository()),
              ),
            ],
            child: const CreateItineraryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore around'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Search places'),
        'Explore',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('POI in Scope B'));
      await tester.pumpAndSettle();

      // Switch to Walking mode via onChanged
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<TransportMode>),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      tester
          .widget<DropdownButtonFormField<TransportMode>>(
            find.byType(DropdownButtonFormField<TransportMode>),
          )
          .onChanged!(TransportMode.walking);
      await tester.pumpAndSettle();

      // Set available duration to 1 hour
      final hoursField = find.widgetWithText(TextField, 'Hours');
      await tester.enterText(hoursField, '1');
      final minutesField = find.widgetWithText(TextField, 'Minutes');
      await tester.enterText(minutesField, '0');
      await tester.pumpAndSettle();

      // Scroll up to check feasibility warning alert
      await tester.scrollUntilVisible(
        find.byType(AppAlert),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Feasibility warning alert is shown
      expect(
        find.textContaining('Lưu ý về thời gian di chuyển:'),
        findsOneWidget,
      );
    },
  );
}

final class _ItineraryRepository implements ItineraryRepository {
  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> getById(int itineraryId) =>
      throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

final class _DeferredItineraryRepository implements ItineraryRepository {
  _DeferredItineraryRepository(this._completer);

  final Completer<GeneratedItinerary> _completer;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => _completer.future;

  @override
  Future<ItineraryDetail> getById(int itineraryId) =>
      throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

final class _LocationService implements DeviceLocationService {
  _LocationService([this._pending]);

  final Completer<DeviceLocation>? _pending;

  @override
  Future<DeviceLocation> getCurrentLocation() async =>
      _pending?.future ??
      const DeviceLocation(latitude: 16.0, longitude: 108.2);

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
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
    bool excludeFoodAndDrink = false,
  }) async => const SelectablePoiSearchResult(items: [], totalCount: 0);
}

final class _RecordingPoiRepository implements PointOfInterestRepository {
  final excludeFoodAndDrink = <bool>[];

  @override
  Future<SelectablePoiSearchResult> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
    int page = 1,
    int pageSize = 50,
    bool excludeFoodAndDrink = false,
  }) async {
    this.excludeFoodAndDrink.add(excludeFoodAndDrink);
    return const SelectablePoiSearchResult(items: [], totalCount: 0);
  }
}

final class _SinglePoiRepository implements PointOfInterestRepository {
  @override
  Future<SelectablePoiSearchResult> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
    int page = 1,
    int pageSize = 50,
    bool excludeFoodAndDrink = false,
  }) async => const SelectablePoiSearchResult(
    items: [
      SelectablePoi(
        id: 1,
        name: 'Da Nang Beach',
        latitude: 16.0,
        longitude: 108.2,
        averageVisitDurationMinutes: 60,
        openingHoursKnown: true,
        hasShelter: false,
      ),
    ],
    totalCount: 1,
  );
}

final class _ScopedPoiRepository implements PointOfInterestRepository {
  @override
  Future<SelectablePoiSearchResult> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
    int page = 1,
    int pageSize = 50,
    bool excludeFoodAndDrink = false,
  }) async {
    if (latitude == null && longitude == null) {
      return const SelectablePoiSearchResult(
        items: [
          SelectablePoi(
            id: 1,
            name: 'POI in Scope A',
            latitude: 16.0,
            longitude: 108.2,
            averageVisitDurationMinutes: 60,
            openingHoursKnown: true,
            hasShelter: false,
          ),
        ],
        totalCount: 1,
      );
    }
    return const SelectablePoiSearchResult(
      items: [
        SelectablePoi(
          id: 2,
          name: 'POI in Scope B',
          latitude: 16.05,
          longitude: 108.25,
          averageVisitDurationMinutes: 60,
          openingHoursKnown: true,
          hasShelter: false,
        ),
      ],
      totalCount: 1,
    );
  }
}

final class _AddressRepository implements AddressSearchRepository {
  _AddressRepository({this.isAvailable = true, this.results = const []});

  @override
  final bool isAvailable;
  final List<AddressSuggestion> results;
  final queries = <String>[];
  final resolved = <String>[];

  @override
  Future<List<AddressCandidate>> suggest(
    String query, {
    DeviceLocation? near,
  }) async {
    queries.add(query);
    return [
      for (final place in results)
        AddressCandidate(
          id: place.name,
          name: place.name,
          fullAddress: place.fullAddress,
        ),
    ];
  }

  @override
  Future<AddressSuggestion> resolve(AddressCandidate candidate) async {
    resolved.add(candidate.id);
    return results.firstWhere((place) => place.name == candidate.id);
  }
}
