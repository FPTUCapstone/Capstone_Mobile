import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/tour_search/data/datasources/tour_search_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/data/repositories/tour_search_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';

import 'support/dev_search_evidence.dart';

/// Opt-in: existing backend/embedding/Qdrant/SQL must be running with owned seed.
/// Only reads HTTP. This harness never starts providers or modifies databases.
void main() {
  final enabled = Platform.environment['TM70_MOBILE_LIVE_E2E'] == '1';
  test(
    'real Mobile Cubit → Dio → dev Search API pipeline',
    () async {
      final uri = Uri.parse(Platform.environment['TM70_E2E_URL'] ?? '');
      expect(
        ['127.0.0.1', 'localhost', '::1'],
        contains(uri.host),
        reason: 'Lab endpoint must be loopback.',
      );
      final keyFile = Platform.environment['TM70_E2E_KEY_FILE'];
      expect(
        keyFile,
        isNotNull,
        reason: 'Supply key using private file outside repository.',
      );
      final key = (await File(keyFile!).readAsString()).trim();
      expect(key.isNotEmpty, isTrue);
      final config = AppConfig(
        environment: Environment.development,
        apiBaseUrl: uri,
        devSearchV2: true,
        devSearchKey: key,
      );
      final client = DioClient(config: config, secureStorage: _Storage());
      // Suppress request logs in the live evidence, including query input.
      client.dio.interceptors.removeWhere(
        (item) => item.runtimeType.toString() == 'AppLoggingInterceptor',
      );
      final evidence = <Map<String, Object?>>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            evidence.add(devSearchEvidence(response, credential: key));
            handler.next(response);
          },
          onError: (error, handler) {
            final response = error.response;
            if (response != null) {
              evidence.add(devSearchEvidence(response, credential: key));
            }
            handler.next(error);
          },
        ),
      );
      addTearDown(() async {
        final evidencePath = Platform.environment['TM70_E2E_EVIDENCE_FILE'];
        if (evidencePath != null && evidencePath.isNotEmpty) {
          final file = File(evidencePath).absolute;
          final repo = Directory.current.absolute.path;
          expect(
            file.path.toLowerCase().startsWith(
              '${repo.toLowerCase()}${Platform.pathSeparator}',
            ),
            isFalse,
            reason: 'Evidence destination must be outside repository.',
          );
          await file.writeAsString(
            '${evidence.map(jsonEncode).join('\n')}\n',
            flush: true,
          );
        }
      });
      addTearDown(client.dio.close);
      final source = DioTourSearchRemoteDataSource(client, config: config);
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(TourSearchRepositoryImpl(source)),
        devSearchEnabled: true,
      );
      addTearDown(cubit.close);
      await HttpOverrides.runWithHttpOverrides(() async {
        final categories = await source.loadCategories();
        expect(categories, isNotEmpty);
        for (final mode in ['lexical', 'semantic', 'hybrid']) {
          await cubit.applyV2Query(
            TourSearchQuery(
              keyword:
                  Platform.environment['TM70_E2E_QUERY'] ??
                  'nghỉ dưỡng biển yên tĩnh',
              mode: mode,
              pageSize: 1,
            ),
          );
          expect(
            cubit.state.failure,
            isNull,
            reason: '$mode dependency must be available.',
          );
          expect(cubit.state.validationFailure, isNull);
          expect(cubit.state.totalCount, greaterThan(0));
          expect(cubit.state.items, hasLength(1));
          if (cubit.state.canLoadMore) {
            final first = cubit.state.items.single.tourId;
            await cubit.loadNextPage();
            expect(cubit.state.failure, isNull);
            expect(cubit.state.page, 2);
            expect(
              cubit.state.items.map((item) => item.tourId).toSet().length,
              cubit.state.items.length,
            );
            expect(cubit.state.items.first.tourId, first);
          }
        }
        await cubit.applyV2Query(
          TourSearchQuery(
            category: categories.first.code,
            minPrice: 0,
            maxPrice: 0,
            durationDays: 999999,
            minimumRating: 5,
            departureDate: DateTime(2000),
            endDate: DateTime(2000, 1, 2),
          ),
        );
        expect(cubit.state.failure, isNull);
        expect(cubit.state.validationFailure, isNull);
        expect(cubit.state.totalCount, 0);
        expect(cubit.state.items, isEmpty);
      }, _RealHttp());
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealHttp extends HttpOverrides {}

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
