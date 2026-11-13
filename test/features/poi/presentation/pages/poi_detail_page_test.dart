import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_favorite_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/set_poi_favorite_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_favorite_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/poi_detail_page.dart';

import '../cubit/poi_favorite_cubit_test.dart';

void main() {
  testWidgets('renders closed day with null hours from Backend v7', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cubit = PoiDetailCubit(GetPoiDetailUseCase(_DetailRepository()));
    addTearDown(cubit.close);
    await cubit.load('1');

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: PoiDetailPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Da Lat Flower Park'), findsOneWidget);
    expect(find.text('Công viên hoa thử nghiệm TM-98'), findsOneWidget);
    expect(find.text('08:00 – 17:00'), findsOneWidget);
    expect(find.text('Đóng cửa'), findsWidgets);
    // Unknown price: never "free".
    expect(find.text('Chưa có thông tin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('favorite heart', () {
    /// Registers the favorite cubit like the app does, on top of [favorites].
    void registerFavorites(FakePoiFavoriteRepository favorites) {
      serviceLocator.registerFactory<PoiFavoriteCubit>(
        () => PoiFavoriteCubit(
          getFavorite: GetPoiFavoriteUseCase(favorites),
          setFavorite: SetPoiFavoriteUseCase(favorites),
        ),
      );
      addTearDown(() => serviceLocator.unregister<PoiFavoriteCubit>());
    }

    Future<void> pumpPage(
      WidgetTester tester, {
      required bool isTraveler,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = PoiDetailCubit(GetPoiDetailUseCase(_DetailRepository()));
      addTearDown(cubit.close);
      await cubit.load('1');
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(home: PoiDetailPage(isTraveler: isTraveler)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden when no traveler is signed in', (tester) async {
      final favorites = FakePoiFavoriteRepository(saved: true);
      registerFavorites(favorites);

      await pumpPage(tester, isTraveler: false);

      expect(find.text('Da Lat Flower Park'), findsOneWidget);
      expect(find.byTooltip('Yêu thích'), findsNothing);
      expect(find.byTooltip('Bỏ yêu thích'), findsNothing);
      expect(favorites.calls, isEmpty);
    });

    testWidgets('is hidden when favorites are not available', (tester) async {
      await pumpPage(tester, isTraveler: true);

      expect(find.text('Da Lat Flower Park'), findsOneWidget);
      expect(find.byTooltip('Yêu thích'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a saved favorite as on', (tester) async {
      final favorites = FakePoiFavoriteRepository(saved: true);
      registerFavorites(favorites);

      await pumpPage(tester, isTraveler: true);

      expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(favorites.calls, ['get:1']);
    });

    testWidgets('a tap turns it on and another tap turns it off', (
      tester,
    ) async {
      final favorites = FakePoiFavoriteRepository();
      registerFavorites(favorites);
      await pumpPage(tester, isTraveler: true);

      expect(find.byTooltip('Yêu thích'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byTooltip('Yêu thích'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(favorites.calls.last, 'set:1:true');

      await tester.tap(find.byTooltip('Bỏ yêu thích'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Yêu thích'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(favorites.calls.last, 'set:1:false');
    });

    testWidgets('fills at once, before the save answers', (tester) async {
      final favorites = FakePoiFavoriteRepository()
        ..pendingSave = Completer<void>();
      registerFavorites(favorites);
      await pumpPage(tester, isTraveler: true);

      await tester.tap(find.byTooltip('Yêu thích'));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);

      favorites.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('a failed save rolls back and tells the traveler', (
      tester,
    ) async {
      final favorites = FakePoiFavoriteRepository()
        ..saveFailure = const NetworkFailure();
      registerFavorites(favorites);
      await pumpPage(tester, isTraveler: true);

      await tester.tap(find.byTooltip('Yêu thích'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Yêu thích'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(
        find.text('Chưa lưu được yêu thích. Vui lòng thử lại.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed turn-off rolls back to on', (tester) async {
      final favorites = FakePoiFavoriteRepository(saved: true)
        ..saveFailure = const ServerFailure();
      registerFavorites(favorites);
      await pumpPage(tester, isTraveler: true);

      await tester.tap(find.byTooltip('Bỏ yêu thích'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(
        find.text('Chưa lưu được yêu thích. Vui lòng thử lại.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load leaves the heart off and the page intact', (
      tester,
    ) async {
      registerFavorites(
        FakePoiFavoriteRepository(loadFailure: const NetworkFailure()),
      );

      await pumpPage(tester, isTraveler: true);

      expect(find.text('Da Lat Flower Park'), findsOneWidget);
      expect(find.byTooltip('Yêu thích'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _DetailRepository implements PoiRepository {
  @override
  Future<PoiDetail> getPoiDetail(int id) async => PoiDetailModel.fromJson({
    'id': 1,
    'name': 'Da Lat Flower Park',
    'description': 'Công viên hoa thử nghiệm TM-98',
    'status': 'Active',
    'categoryId': 1,
    'categoryName': 'Attraction',
    'latitude': 11.941755,
    'longitude': 108.438278,
    'address': 'Đà Lạt, Lâm Đồng',
    'indoorOutdoor': 'Mixed',
    'averageVisitDurationMinutes': 90,
    'hasShelter': true,
    'scenicScore': null,
    'photoRating': null,
    'averageRating': null,
    'reviewCount': 0,
    'isOpenNow': true,
    'openingHours': [
      {'dayOfWeek': 0, 'openTime': null, 'closeTime': null, 'isClosed': true},
      {
        'dayOfWeek': 1,
        'openTime': '08:00:00',
        'closeTime': '17:00:00',
        'isClosed': false,
      },
    ],
    'photos': [],
    'tags': [
      {'id': 2, 'name': 'Family'},
      {'id': 1, 'name': 'Nature'},
    ],
    'createdAtUtc': '2026-09-09T11:20:00.2254061+00:00',
    'updatedAtUtc': '2026-09-09T11:20:00.2254061+00:00',
  }).toEntity();

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) => throw UnimplementedError();
}
