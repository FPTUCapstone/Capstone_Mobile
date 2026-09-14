import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/data/datasources/poi_remote_data_source.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_page_model.dart';
import 'package:trip_mate_mobile/features/poi/data/repositories/poi_repository_impl.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';

void main() {
  test('repository maps data models to domain entities', () async {
    final repository = PoiRepositoryImpl(_SuccessfulDataSource());

    final page = await repository.getPois(const PoiQuery());

    expect(page.items.single.name, 'Cầu Rồng');
  });

  test('repository exposes typed failure instead of DioException', () async {
    final repository = PoiRepositoryImpl(_FailingDataSource());

    expect(() => repository.getPoiDetail(999), throwsA(isA<NotFoundFailure>()));
  });
}

class _SuccessfulDataSource implements PoiRemoteDataSource {
  @override
  Future<PoiPageModel> getPois(PoiQuery query) async => PoiPageModel.fromJson({
    'page': 1,
    'pageSize': 20,
    'totalCount': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 1,
        'name': 'Cầu Rồng',
        'categoryId': 1,
        'categoryName': 'Danh thắng',
        'latitude': 16.061,
        'longitude': 108.226,
        'address': null,
        'indoorOutdoor': 'Outdoor',
        'averageVisitDurationMinutes': 60,
        'hasShelter': false,
        'averageRating': 4.7,
        'reviewCount': 20,
        'thumbnailUrl': null,
        'distanceKm': null,
        'isOpenNow': true,
      },
    ],
  });

  @override
  Future<PoiDetailModel> getPoiDetail(int id) => throw UnimplementedError();
}

class _FailingDataSource implements PoiRemoteDataSource {
  @override
  Future<PoiPageModel> getPois(PoiQuery query) => throw UnimplementedError();

  @override
  Future<PoiDetailModel> getPoiDetail(int id) {
    final request = RequestOptions(path: '/api/v1/pois/$id');
    throw DioException(
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: 404,
        data: const {'errorCode': 'Poi.NotFound'},
      ),
      type: DioExceptionType.badResponse,
    );
  }
}
