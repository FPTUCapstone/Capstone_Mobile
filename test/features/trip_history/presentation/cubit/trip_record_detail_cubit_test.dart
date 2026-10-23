import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class _Repository implements TripRecordsRepository {
  final List<(TripRecordKind, int)> requests = [];
  Future<TripRecordDetail> Function() onDetail = () =>
      const DemoTripRecordsRepository().getDetail(
        TripRecordKind.itinerary,
        5001,
      );

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) =>
      throw UnimplementedError();

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) {
    requests.add((kind, id));
    return onDetail();
  }
}

({TripRecordDetailCubit cubit, _Repository repository}) _build() {
  final repository = _Repository();
  return (
    cubit: TripRecordDetailCubit(
      useCase: TripRecordsUseCase(repository),
      reference: const TripRecordRef(kind: TripRecordKind.itinerary, id: 5001),
    ),
    repository: repository,
  );
}

void main() {
  test('starts in loading', () {
    final built = _build();
    addTearDown(built.cubit.close);

    expect(built.cubit.state.status, TripRecordDetailStatus.loading);
    expect(built.cubit.state.detail, isNull);
  });

  test('load asks for the (kind, id) pair and becomes ready', () async {
    final built = _build();
    addTearDown(built.cubit.close);

    await built.cubit.load();

    expect(built.repository.requests.single, (TripRecordKind.itinerary, 5001));
    expect(built.cubit.state.status, TripRecordDetailStatus.ready);
    expect(built.cubit.state.detail, isA<ItineraryTripDetail>());
    expect(built.cubit.state.message, isNull);
  });

  group('failures', () {
    final cases = <String, (Failure, String, bool)>{
      'NotFoundFailure': (
        const NotFoundFailure(),
        TripHistoryStringsEn.tripRecordUnavailable,
        false,
      ),
      'AuthenticationFailure': (
        const AuthenticationFailure(),
        TripHistoryStringsEn.permissionDenied,
        false,
      ),
      'PermissionFailure': (
        const PermissionFailure(),
        TripHistoryStringsEn.permissionDenied,
        false,
      ),
      'NetworkFailure': (
        const NetworkFailure(),
        TripHistoryStringsEn.errorMessageGeneric,
        true,
      ),
      'ServerFailure with a code': (
        const ServerFailure('trip_history.invalid_response'),
        TripHistoryStringsEn.errorMessageGeneric,
        true,
      ),
    };

    for (final entry in cases.entries) {
      test('${entry.key} becomes a safe message', () async {
        final built = _build();
        addTearDown(built.cubit.close);
        built.repository.onDetail = () async => throw entry.value.$1;

        await built.cubit.load();

        expect(built.cubit.state.status, TripRecordDetailStatus.failure);
        expect(built.cubit.state.message, entry.value.$2);
        expect(built.cubit.state.canRetry, entry.value.$3);
      });
    }

    test('an unexpected exception is reported generically', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onDetail = () async => throw StateError('SELECT *');

      await built.cubit.load();

      expect(
        built.cubit.state.message,
        TripHistoryStringsEn.errorMessageGeneric,
      );
      expect(built.cubit.state.canRetry, isTrue);
    });

    test('retry loads again and recovers', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onDetail = () async => throw const NetworkFailure();
      await built.cubit.load();
      built.repository.onDetail = () => const DemoTripRecordsRepository()
          .getDetail(TripRecordKind.itinerary, 5001);

      await built.cubit.retry();

      expect(built.repository.requests, hasLength(2));
      expect(built.cubit.state.status, TripRecordDetailStatus.ready);
      expect(built.cubit.state.message, isNull);
    });
  });

  test(
    'a late answer of an earlier attempt never replaces a newer one',
    () async {
      final built = _build();
      addTearDown(built.cubit.close);
      final slow = Completer<TripRecordDetail>();
      var calls = 0;
      built.repository.onDetail = () {
        calls++;
        if (calls == 1) return slow.future;
        return const DemoTripRecordsRepository().getDetail(
          TripRecordKind.itinerary,
          5001,
        );
      };

      final first = built.cubit.load();
      await built.cubit.retry();
      slow.completeError(const NetworkFailure());
      await first;

      expect(built.cubit.state.status, TripRecordDetailStatus.ready);
    },
  );

  test('closing while loading does not throw', () async {
    final built = _build();
    final slow = Completer<TripRecordDetail>();
    built.repository.onDetail = () => slow.future;

    final load = built.cubit.load();
    await built.cubit.close();
    slow.complete(
      await const DemoTripRecordsRepository().getDetail(
        TripRecordKind.itinerary,
        5001,
      ),
    );

    await expectLater(load, completes);
  });
}
