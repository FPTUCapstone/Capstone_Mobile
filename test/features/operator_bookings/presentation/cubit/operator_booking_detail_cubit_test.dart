import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/operator_bookings_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';

import '../../operator_bookings_fixtures.dart';

final class _FakeRepository implements OperatorBookingsRepository {
  final List<String> requested = [];
  Future<OperatorBookingDetail> Function(String id)? onDetail;

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) {
    requested.add(bookingId);
    final handler = onDetail;
    return handler == null
        ? Future.value(OperatorBookingsJson.detail(detailJson(id: bookingId)))
        : handler(bookingId);
  }

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() =>
      throw UnimplementedError();
}

void main() {
  late _FakeRepository repository;
  late OperatorBookingDetailCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = OperatorBookingDetailCubit(
      getBooking: GetOperatorBookingUseCase(repository),
      bookingId: '1201',
    );
  });

  tearDown(() => cubit.close());

  test('starts loading for the requested booking', () {
    expect(cubit.state.status, OperatorBookingDetailStatus.loading);
    expect(cubit.state.detail, isNull);
  });

  test('load shows the detail returned for that booking', () async {
    final states = <OperatorBookingDetailState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load();
    await subscription.cancel();

    expect(repository.requested, ['1201']);
    expect(states.first.status, OperatorBookingDetailStatus.loading);
    expect(cubit.state.status, OperatorBookingDetailStatus.success);
    expect(cubit.state.detail!.bookingId, '1201');
    expect(cubit.state.detail!.participants, hasLength(2));
    expect(cubit.state.errorMessage, isNull);
  });

  test(
    'keeps canCancel and cancelBlockedReason in the entity for the UC-41 task',
    () async {
      repository.onDetail = (id) async => OperatorBookingsJson.detail(
        detailJson(id: id)
          ..['canCancel'] = false
          ..['cancelBlockedReason'] = 'CheckedIn',
      );

      await cubit.load();

      expect(cubit.state.detail!.canCancel, isFalse);
      expect(
        cubit.state.detail!.cancelBlockedReason,
        OperatorCancelBlockedReason.checkedIn,
      );
    },
  );

  for (final (label, failure) in <(String, Failure)>[
    ('a 401', const AuthenticationFailure()),
    ('a 403', const PermissionFailure()),
    ('a 404', const NotFoundFailure()),
  ]) {
    test('$label is the access message and cannot be retried', () async {
      repository.onDetail = (_) => Future.error(failure);

      await cubit.load();

      expect(cubit.state.status, OperatorBookingDetailStatus.failure);
      expect(cubit.state.errorMessage, OperatorBookingsStringsEn.accessDenied);
      expect(cubit.state.canRetry, isFalse);
      expect(cubit.state.detail, isNull);
    });
  }

  for (final (label, failure) in <(String, Failure)>[
    ('a network failure', const NetworkFailure()),
    ('a server failure', const ServerFailure('private detail')),
    ('a malformed body', const ServerFailure(operatorBookingInvalidResponse)),
  ]) {
    test(
      '$label is the generic message with Retry and never exposes details',
      () async {
        repository.onDetail = (_) => Future.error(failure);

        await cubit.load();

        expect(cubit.state.status, OperatorBookingDetailStatus.failure);
        expect(cubit.state.errorMessage, OperatorBookingsStringsEn.systemError);
        expect(cubit.state.canRetry, isTrue);
      },
    );
  }

  test('retry asks again and then shows the detail', () async {
    repository.onDetail = (_) => Future.error(const NetworkFailure());
    await cubit.load();
    repository.onDetail = null;

    await cubit.retry();

    expect(repository.requested, ['1201', '1201']);
    expect(cubit.state.status, OperatorBookingDetailStatus.success);
    expect(cubit.state.errorMessage, isNull);
  });

  test('a newer request supersedes an older answer', () async {
    final slow = Completer<OperatorBookingDetail>();
    var call = 0;
    repository.onDetail = (id) => ++call == 1
        ? slow.future
        : Future.value(
            OperatorBookingsJson.detail(
              detailJson(id: id)..['bookingCode'] = 'BK-NEW',
            ),
          );
    final first = cubit.load();

    await cubit.retry();
    slow.complete(
      OperatorBookingsJson.detail(detailJson()..['bookingCode'] = 'BK-OLD'),
    );
    await first;

    expect(cubit.state.detail!.bookingCode, 'BK-NEW');
  });

  test(
    'a late answer after close changes nothing and throws nothing',
    () async {
      final gate = Completer<OperatorBookingDetail>();
      repository.onDetail = (_) => gate.future;
      final loading = cubit.load();

      await cubit.close();
      gate.complete(OperatorBookingsJson.detail(detailJson()));

      await loading;
    },
  );
}
