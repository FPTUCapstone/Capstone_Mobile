import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';

void main() {
  testWidgets('list and map remain usable at 320px with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = PoiListCubit(getPois: GetPoisUseCase(_PageRepository()));
    addTearDown(cubit.close);
    await cubit.loadInitial();

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            );
          },
          home: const ExplorePoiPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Khám phá miền Trung'), findsOneWidget);
    expect(find.byKey(const Key('poi-card-1')), findsOneWidget);
    final listException = tester.takeException();
    if (listException case final FlutterError error) {
      debugPrint(error.toStringDeep());
    }
    expect(listException, isNull);

    await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'Bản đồ'));
    await tester.pumpAndSettle();

    expect(find.text('Bản đồ minh họa vị trí'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PageRepository implements PoiRepository {
  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async {
    return const PagedPoiResult(
      page: 1,
      pageSize: 20,
      totalCount: 1,
      totalPages: 1,
      items: [
        PoiSummary(
          id: 1,
          name: 'Ngũ Hành Sơn (Marble Mountains)',
          categoryId: 3,
          categoryName: 'Di sản & Danh thắng',
          latitude: 16.0036,
          longitude: 108.263,
          indoorOutdoor: 'Mixed',
          averageVisitDurationMinutes: 90,
          hasShelter: true,
          averageRating: 4.8,
          reviewCount: 1284,
          distanceKm: 2.4,
          isOpenNow: true,
        ),
      ],
    );
  }

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}
