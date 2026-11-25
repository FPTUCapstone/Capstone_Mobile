import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
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

    expect(find.text('Dùng vị trí hiện tại'), findsOneWidget);
    expect(find.byKey(const Key('choose_start_place_field')), findsOneWidget);
    expect(find.textContaining('latitude', findRichText: true), findsNothing);
    expect(find.textContaining('longitude', findRichText: true), findsNothing);

    await tester.tap(find.text('Dùng vị trí hiện tại'));
    await tester.pumpAndSettle();

    expect(find.text('Vị trí hiện tại'), findsOneWidget);
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

    await tester.tap(find.text('Dùng vị trí hiện tại'));
    await tester.pump();

    expect(find.text('Đang tìm vị trí…'), findsOneWidget);
    expect(find.text('Dùng vị trí hiện tại'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('use_current_location_button')),
    );
    expect(button.onPressed, isNull);

    pending.complete(const DeviceLocation(latitude: 16.0, longitude: 108.2));
    await tester.pumpAndSettle();

    expect(find.text('Vị trí hiện tại'), findsOneWidget);
    expect(find.text('Dùng vị trí hiện tại'), findsOneWidget);
  });

  testWidgets('does not show Public transit as a transport option', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Phương tiện di chuyển'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Phương tiện công cộng'), findsNothing);
    expect(find.text('Public transit'), findsNothing);
    expect(find.byKey(const ValueKey('transport_motorbike')), findsOneWidget);
    expect(find.byKey(const ValueKey('transport_walking')), findsOneWidget);
    expect(find.byKey(const ValueKey('transport_car')), findsOneWidget);
  });

  testWidgets('shows search radius slider and optional budget field', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('1 km (Gần)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 1);
    expect(slider.max, 100);
    expect(slider.divisions, 99);
    expect(find.byKey(const Key('search_radius_map_card')), findsOneWidget);
    expect(find.text('Bản đồ khu vực & Bán kính tìm kiếm'), findsOneWidget);
    expect(find.text('Bán kính tìm kiếm'), findsOneWidget);
    expect(find.text('1 km (Gần)'), findsOneWidget);
    expect(find.text('50 km (Ngoại ô)'), findsOneWidget);
    expect(find.text('100 km (Liên tỉnh)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Ngân sách (VNĐ, tùy chọn)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ngân sách (VNĐ, tùy chọn)'), findsOneWidget);
  });

  testWidgets('warns when the search radius is above 30 km', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bán kính tìm kiếm'),
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

  testWidgets('must-see picker allows restaurants (Food Tour support)', (
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
    await tester.tap(find.text('Dùng vị trí hiện tại'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thêm điểm nhất định ghé'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm điểm nhất định ghé'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tìm kiếm địa điểm'),
      'Museum',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.excludeFoodAndDrink, [false]);
  });

  testWidgets('generate button is always visible in the sticky footer', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Tạo lịch trình tối ưu'),
      findsOneWidget,
    );
  });

  testWidgets('rejects a non-positive budget instead of omitting it', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ngân sách (VNĐ, tùy chọn)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ngân sách (VNĐ, tùy chọn)'),
      '0',
    );
    await tester.pump();

    expect(
      find.text('Nhập ngân sách lớn hơn 0 hoặc để trống.'),
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

    testWidgets('duration preset updates hours and minutes fields', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('available_hours_field')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 giờ'));
      await tester.pump();

      final hoursField = tester.widget<TextField>(
        find.byKey(const Key('available_hours_field')),
      );
      final minutesField = tester.widget<TextField>(
        find.byKey(const Key('available_minutes_field')),
      );
      expect(hoursField.controller?.text, '4');
      expect(minutesField.controller?.text, '0');
    });

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

      expect(
        helperText(tester),
        startsWith('Từ 1 giờ đến 3 ngày. Kết thúc lúc '),
      );
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

      expect(helperText(tester), 'Thời lượng tối thiểu là 1 giờ.');
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

      expect(helperText(tester), 'Chuyến đi tối đa 72 giờ (3 ngày).');
    });

    testWidgets('rejects more than 59 minutes', (tester) async {
      await showDurationFields(tester);

      await tester.enterText(
        find.byKey(const Key('available_minutes_field')),
        '75',
      );
      await tester.pump();

      expect(helperText(tester), 'Nhập số giờ nguyên và 0–59 phút.');
    });

    testWidgets('opens Vietnamese Coastal date and wheel time bottom sheets', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('available_hours_field')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start_date_field')));
      await tester.pumpAndSettle();

      // Open Start Date bottom sheet and pick "Ngày mai"
      await tester.tap(find.byKey(const Key('start_date_field')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ngày bắt đầu'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Ngày mai'), findsOneWidget);
      expect(find.text('Cuối tuần'), findsOneWidget);
      await tester.tap(find.text('Ngày mai'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ngày bắt đầu'), findsNothing);

      // Open Start Time wheel bottom sheet and pick "08:00"
      await tester.tap(find.byKey(const Key('start_time_field')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn giờ xuất phát'), findsOneWidget);
      expect(find.byKey(const Key('hour_wheel')), findsOneWidget);
      expect(find.byKey(const Key('minute_wheel')), findsOneWidget);
      await tester.tap(find.text('08:00').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận giờ'));
      await tester.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
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

    await tester.tap(find.text('Dùng vị trí hiện tại'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('explore_around_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tìm kiếm địa điểm'),
      'Da Nang',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Da Nang Beach'));
    await tester.pumpAndSettle();

    final budgetFieldFinder = find.widgetWithText(
      TextField,
      'Ngân sách (VNĐ, tùy chọn)',
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
      'Tạo lịch trình tối ưu',
    );
    await tester.tap(generateButton);
    await tester.pump();

    expect(tester.widget<TextField>(budgetFieldFinder).enabled, isFalse);

    completer.completeError(Exception('Failed to generate'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(budgetFieldFinder).enabled, isTrue);
  });

  group('UC-10 pending explanation handoff', () {
    GeneratedItinerary generated({required bool pending}) => GeneratedItinerary(
      schedulingRequestId: 1,
      itineraryId: 42,
      title: 'Trip',
      status: 'Draft',
      totalEstimatedCost: 0,
      totalDurationMinutes: 60,
      explanationPending: pending,
      items: [
        GeneratedItineraryItem(
          sequenceNo: 1,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: DateTime.utc(2026, 9, 20, 1),
          plannedDeparture: DateTime.utc(2026, 9, 20, 2),
          stayDurationMinutes: 60,
          isMandatory: false,
          friendlyExplanation: ' Template ',
        ),
      ],
    );

    /// Generates an itinerary and returns the `extra` the detail route got.
    Future<Object?> generateAndCaptureExtra(
      WidgetTester tester,
      GeneratedItinerary result,
    ) async {
      Object? extra;
      final completer = Completer<GeneratedItinerary>();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const CreateItineraryPage()),
          GoRoute(
            path: AppRoutes.itineraryDetail,
            name: AppRouteNames.itineraryDetail,
            builder: (_, state) {
              extra = state.extra;
              return const Scaffold(body: Text('detail page'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => CreateItineraryCubit(
                repository: _DeferredItineraryRepository(completer),
              ),
            ),
            BlocProvider(
              create: (_) => PoiSearchCubit(
                locationService: _LocationService(),
                repository: _SinglePoiRepository(),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dùng vị trí hiện tại'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('explore_around_field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm kiếm địa điểm'),
        'Da Nang',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Da Nang Beach'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Tạo lịch trình tối ưu'),
      );
      await tester.pump();
      completer.complete(result);
      await tester.pumpAndSettle();
      expect(find.text('detail page'), findsOneWidget);
      return extra;
    }

    testWidgets('passes a pending explanation to the detail route', (
      tester,
    ) async {
      final extra = await generateAndCaptureExtra(
        tester,
        generated(pending: true),
      );

      expect(extra, isA<PendingExplanation>());
      final pending = extra! as PendingExplanation;
      expect(pending.itineraryId, 42);
      expect(pending.template, {1: 'Template'});
    });

    testWidgets('passes nothing when the explanation is not pending', (
      tester,
    ) async {
      final extra = await generateAndCaptureExtra(
        tester,
        generated(pending: false),
      );

      expect(extra, isNull);
    });
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

      await tester.tap(find.byKey(const Key('choose_start_place_field')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(TextField, 'Địa chỉ hoặc tên địa điểm'),
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

    await tester.tap(find.byKey(const Key('choose_start_place_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Địa chỉ hoặc tên địa điểm'),
      '123 nguyen van linh',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(addresses.queries, ['123 nguyen van linh']);
    expect(find.text('Địa chỉ'), findsOneWidget);
    expect(find.text('Địa điểm'), findsOneWidget);
    await tester.tap(find.text('123 Nguyễn Văn Linh'));
    await tester.pumpAndSettle();

    expect(addresses.resolved, ['123 Nguyễn Văn Linh']);
    expect(
      find.text('123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng, Việt Nam'),
      findsOneWidget,
    );
    // Explore around is now unlocked (tapping opens the POI picker)
    await tester.tap(find.byKey(const Key('explore_around_field')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn địa điểm'), findsOneWidget);
  });

  testWidgets('a catalog place can still be the starting point', (
    tester,
  ) async {
    await pumpWithAddresses(tester, _AddressRepository());

    await tester.tap(find.byKey(const Key('choose_start_place_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Địa chỉ hoặc tên địa điểm'),
      'Scope',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy địa chỉ phù hợp.'), findsOneWidget);
    await tester.tap(find.text('POI in Scope A'));
    await tester.pumpAndSettle();

    expect(find.text('POI in Scope A'), findsOneWidget);
    expect(find.text('Chưa chọn điểm xuất phát'), findsNothing);
  });

  testWidgets('without Mapbox the start search covers catalog places only', (
    tester,
  ) async {
    final addresses = _AddressRepository(isAvailable: false);
    await pumpWithAddresses(tester, addresses);

    await tester.tap(find.byKey(const Key('choose_start_place_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên địa điểm'),
      'Scope',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Địa chỉ'), findsNothing);
    expect(find.text('POI in Scope A'), findsOneWidget);
    expect(addresses.queries, isEmpty);
  });

  testWidgets('invalidates stale POI results when picker scope changes', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const Key('choose_start_place_field')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Địa chỉ hoặc tên địa điểm'),
      'ScopeA',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('POI in Scope A'), findsOneWidget);

    Navigator.of(tester.element(find.text('POI in Scope A'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dùng vị trí hiện tại'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('explore_around_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tìm kiếm địa điểm'),
      'Explore',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('POI in Scope B'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thêm điểm nhất định ghé'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm điểm nhất định ghé'));
    await tester.pumpAndSettle();

    expect(find.text('POI in Scope A'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('POI in Scope B'),
      ),
      findsNothing,
    );
    expect(find.text('Nhập tên để tìm địa điểm.'), findsOneWidget);
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

      await tester.tap(find.text('Dùng vị trí hiện tại'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('explore_around_field')));
      await tester.pumpAndSettle();

      // Verify quick suggestion chips exist in the exploration sheet
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Bà Nà Hills'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Sơn Trà'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm kiếm địa điểm'),
        'Explore',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('POI in Scope B'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('3. Điểm nhất định ghé (tùy chọn)'),
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

      // Scroll back up to verify exploration field still holds the POI
      await tester.scrollUntilVisible(
        find.byKey(const Key('explore_around_field')),
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

      await tester.tap(find.text('Dùng vị trí hiện tại'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('explore_around_field')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm kiếm địa điểm'),
        'Explore',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('POI in Scope B'));
      await tester.pumpAndSettle();

      // Switch to Walking mode via chip tap
      final walkingChip = find.byKey(const ValueKey('transport_walking'));
      await tester.scrollUntilVisible(
        walkingChip,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(walkingChip);
      await tester.pumpAndSettle();
      await tester.tap(walkingChip);
      await tester.pumpAndSettle();

      // Set available duration to 1 hour
      final hoursField = find.byKey(const Key('available_hours_field'));
      await tester.scrollUntilVisible(
        hoursField,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(hoursField);
      await tester.pumpAndSettle();
      await tester.enterText(hoursField, '1');
      await tester.enterText(
        find.byKey(const Key('available_minutes_field')),
        '0',
      );
      await tester.pumpAndSettle();

      // Scroll up to check feasibility warning alert
      await tester.scrollUntilVisible(
        find.byType(AppAlert),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

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
    Map<int, StopRemovalReason> removalReasons = const {},
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
    Map<int, StopRemovalReason> removalReasons = const {},
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
