import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

void main() {
  late _PendingAdapter adapter;
  late TourSearchCubit guest;
  late TourSearchCubit search;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('http://127.0.0.1:5077'),
        devSearchV2: true,
        devSearchKey: 'test-only-key',
      ),
    );
    adapter = _PendingAdapter();
    serviceLocator<DioClient>().dio.httpClientAdapter = adapter;
    guest = serviceLocator<TourSearchCubit>();
    search = serviceLocator<TourSearchCubit>();
  });

  tearDown(() async {
    adapter.completeAll();
    await guest.close();
    await search.close();
    serviceLocator<DioClient>().dio.close(force: true);
    await adapter.started.close();
    await serviceLocator.reset();
  });

  test(
    'independent Guest and Search consumers finish without cross-cancellation',
    () async {
      final guestRequest = guest.applyV2Query(
        const TourSearchQuery(keyword: 'guest', mode: 'semantic'),
      );
      await adapter.waitFor(1);
      final searchRequest = search.applyV2Query(
        const TourSearchQuery(keyword: 'search', mode: 'hybrid'),
      );
      await adapter.waitFor(2);
      final guestWasCancelled = adapter.requests.first.cancelToken!.isCancelled;
      adapter.completeAll();
      await Future.wait([guestRequest, searchRequest]);

      expect(guestWasCancelled, isFalse);
      expect(guest.state.status, TourSearchStatus.success);
      expect(guest.state.failure, isNull);
      expect(search.state.status, TourSearchStatus.success);
      expect(search.state.failure, isNull);
      expect(guest.state.query.keyword, 'guest');
      expect(search.state.query.keyword, 'search');
    },
  );

  test('same Search consumer still cancels its superseded request', () async {
    final oldRequest = search.applyV2Query(
      const TourSearchQuery(keyword: 'old', mode: 'semantic'),
    );
    await adapter.waitFor(1);
    final newRequest = search.applyV2Query(
      const TourSearchQuery(keyword: 'new', mode: 'hybrid'),
    );
    await adapter.waitFor(2);
    expect(adapter.requests.first.cancelToken!.isCancelled, isTrue);
    expect(adapter.requests.last.cancelToken!.isCancelled, isFalse);
    adapter.completeAll();
    await Future.wait([oldRequest, newRequest]);

    expect(search.state.status, TourSearchStatus.success);
    expect(search.state.query.keyword, 'new');
    expect(search.state.failure, isNull);
  });
}

class _PendingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <Completer<ResponseBody>>[];
  final started = StreamController<int>.broadcast(sync: true);

  Future<void> waitFor(int count) async {
    if (requests.length >= count) return;
    await started.stream
        .firstWhere((value) => value >= count)
        .timeout(const Duration(seconds: 5));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final response = Completer<ResponseBody>();
    responses.add(response);
    started.add(requests.length);
    return response.future;
  }

  void completeAll() {
    for (final response in responses) {
      if (!response.isCompleted) {
        response.complete(
          ResponseBody.fromString(
            '{"page":1,"pageSize":20,"totalCount":0,"totalPages":0,"items":[]}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
      }
    }
  }

  @override
  void close({bool force = false}) => completeAll();
}
