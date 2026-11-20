import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/datasources/operator_finance_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/repositories/operator_finance_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';

import 'operator_finance_json_test.dart' show reportJson;

class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}

void main() {
  late DioClient client;
  late OperatorFinanceRepositoryImpl repo;
  final query = RevenueQuery(
    startDate: DateTime(2026, 11),
    endDate: DateTime(2026, 11, 30),
    tourId: 7,
    page: 2,
  );

  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: _Storage(),
    );
    // Transport mapping is isolated here; central auth refresh is covered by its own tests.
    client.dio.interceptors.clear();
    repo = OperatorFinanceRepositoryImpl(
      DioOperatorFinanceRemoteDataSource(client),
    );
  });

  test(
    'uses three GET contracts, date-only inclusive range and page query',
    () async {
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(options.queryParameters.containsKey('operatorId'), isFalse);
            if (options.path.endsWith('/report')) {
              expect(options.queryParameters, {
                'startDate': '2026-11-01',
                'endDate': '2026-11-30',
                'granularity': 'monthly',
                'tourId': 7,
                'page': 2,
                'pageSize': 10,
              });
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: reportJson()..['page'] = 2,
                ),
              );
            } else if (options.path.endsWith('/tours')) {
              handler.resolve(
                Response(requestOptions: options, data: <Object>[]),
              );
            } else {
              expect(options.path, '/api/v1/operator/payout-settlements');
              expect(options.queryParameters, {'page': 2, 'pageSize': 10});
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'pageNumber': 2,
                    'pageSize': 10,
                    'totalCount': 0,
                    'items': <Object>[],
                  },
                ),
              );
            }
          },
        ),
      );
      expect((await repo.loadReport(query)).summary.netAmount, 4500);
      expect(await repo.loadTourOptions(), isEmpty);
      expect((await repo.loadSettlementHistory(page: 2)).pageNumber, 2);
    },
  );

  test('invalid request is rejected before transport', () async {
    var calls = 0;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (_, _) {
          calls++;
        },
      ),
    );
    await expectLater(
      repo.loadReport(query.copyWith(page: 0)),
      throwsA(isA<ValidationFailure>()),
    );
    await expectLater(
      repo.loadSettlementHistory(pageSize: 101),
      throwsA(isA<ValidationFailure>()),
    );
    expect(calls, 0);
  });

  test(
    'malformed live response fails safely rather than zero fallback',
    () async {
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(requestOptions: options, data: {'summary': null}),
            );
          },
        ),
      );
      await expectLater(repo.loadReport(query), throwsA(isA<ServerFailure>()));
    },
  );

  test(
    'does not accept a report page different from the requested page',
    () async {
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(requestOptions: options, data: reportJson()),
            );
          },
        ),
      );
      await expectLater(repo.loadReport(query), throwsA(isA<ServerFailure>()));
    },
  );

  for (final metadata in [(page: 1, pageSize: 10), (page: 2, pageSize: 20)]) {
    test(
      'rejects history mismatch page=${metadata.page} size=${metadata.pageSize}',
      () async {
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'pageNumber': metadata.page,
                    'pageSize': metadata.pageSize,
                    'totalCount': 0,
                    'items': <Object>[],
                  },
                ),
              );
            },
          ),
        );
        await expectLater(
          repo.loadSettlementHistory(page: 2),
          throwsA(isA<ServerFailure>()),
        );
      },
    );
  }

  for (final status in [400, 401, 403, 500]) {
    test('maps HTTP $status without exposing raw server error', () async {
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: status,
                  data: {'detail': 'SQL password secret'},
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        repo.loadTourOptions(),
        throwsA(
          predicate<Failure>(
            (failure) =>
                !failure.message.contains('SQL') &&
                (status == 400
                    ? failure is ValidationFailure
                    : status == 401
                    ? failure is AuthenticationFailure
                    : status == 403
                    ? failure is PermissionFailure
                    : failure is ServerFailure),
          ),
        ),
      );
    });
  }

  test('maps network failures safely', () async {
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );
    await expectLater(repo.loadTourOptions(), throwsA(isA<NetworkFailure>()));
  });
}
