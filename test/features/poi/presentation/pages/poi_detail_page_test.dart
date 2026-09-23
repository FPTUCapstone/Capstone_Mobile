import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/poi_detail_page.dart';

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
    expect(tester.takeException(), isNull);
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
