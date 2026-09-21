import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/data/datasources/tour_search_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/data/models/tour_search_page_model.dart';
import 'package:trip_mate_mobile/features/tour_search/data/repositories/tour_search_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

void main() {
  test('Success: data source returns model -> repo returns entity', () async {
    final dataSource = _MockDataSource();
    dataSource.result = TourSearchPageModel(
      page: 1,
      pageSize: 20,
      totalCount: 1,
      totalPages: 1,
      items: [
        TourSearchItemModel(
          tourId: '123',
          title: 'Test Tour',
          destinations: ['Da Nang'],
          operatorName: 'Test Op',
          durationDays: 2,
          basePrice: 100,
          currency: 'VND',
          representativeScheduleId: null,
          departureAtUtc: null,
          availabilityStatus: 'available',
          remainingSlots: null,
        ),
      ],
    );
    final repository = TourSearchRepositoryImpl(dataSource);

    final result = await repository.searchTours(TourSearchQuery());

    expect(result.items.first.tourId, '123');
    expect(result.items.first.title, 'Test Tour');
  });

  test(
    'DioException with 400 ValidationProblemDetails -> maps to ValidationFailure with fieldErrors',
    () async {
      final dataSource = _MockDataSource();
      dataSource.error = DioException(
        requestOptions: RequestOptions(path: '/api/v1/tours'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/tours'),
          statusCode: 400,
          data: const {
            'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
            'title': 'One or more validation errors occurred.',
            'status': 400,
            'errors': {
              'minPrice': ['minPrice cannot be negative.'],
              'pageSize': ['pageSize must be between 1 and 100.'],
            },
          },
        ),
      );
      final repository = TourSearchRepositoryImpl(dataSource);

      try {
        await repository.searchTours(const TourSearchQuery());
        fail('Expected ValidationFailure');
      } on ValidationFailure catch (failure) {
        expect(failure.fieldErrors, contains('minPrice'));
        expect(failure.fieldErrors['minPrice'], [
          'minPrice cannot be negative.',
        ]);
        expect(failure.fieldErrors, contains('pageSize'));
        expect(failure.fieldErrors['pageSize'], [
          'pageSize must be between 1 and 100.',
        ]);
      }
    },
  );

  test('DioException with timeout -> throws NetworkFailure', () async {
    final dataSource = _MockDataSource();
    dataSource.error = DioException(
      requestOptions: RequestOptions(path: '/api/v1/tours'),
      type: DioExceptionType.connectionTimeout,
    );
    final repository = TourSearchRepositoryImpl(dataSource);

    expect(
      () => repository.searchTours(TourSearchQuery()),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('Generic error -> throws UnknownFailure', () async {
    final dataSource = _MockDataSource();
    dataSource.error = Exception('Random error');
    final repository = TourSearchRepositoryImpl(dataSource);

    expect(
      () => repository.searchTours(TourSearchQuery()),
      throwsA(isA<UnknownFailure>()),
    );
  });
}

class _MockDataSource implements TourSearchRemoteDataSource {
  TourSearchPageModel? result;
  Object? error;

  @override
  Future<TourSearchPageModel> searchTours(TourSearchQuery query) async {
    if (error != null) throw error!;
    return result!;
  }
}
