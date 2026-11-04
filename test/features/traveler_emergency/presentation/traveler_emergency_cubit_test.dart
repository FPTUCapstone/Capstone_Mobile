import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/repositories/traveler_emergency_repository.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_state.dart';

import '../../operator_weather_safety/support/fake_operator_weather_safety_repository.dart'
    show FakeNetworkInfo;
import '../support/traveler_emergency_fixtures.dart';

void main() {
  late _FakeRepository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = _FakeRepository();
    network = FakeNetworkInfo();
  });

  TravelerEmergencyCubit create() => TravelerEmergencyCubit(
    bookingId: 42,
    getStatus: GetTravelerEmergencyStatusUseCase(repository),
    acknowledge: AcknowledgeTravelerEmergencyStatusUseCase(repository),
    networkInfo: network,
  );

  test('loads the committed status from REST', () async {
    final cubit = create();

    await cubit.load();

    expect(cubit.state.status, TravelerEmergencyLoadStatus.ready);
    expect(cubit.state.emergency?.bookingId, 42);
    await cubit.close();
  });

  test('a foreign booking is a Safe 404 and shows nothing', () async {
    repository.failure = const NotFoundFailure();
    final cubit = create();

    await cubit.load();

    expect(cubit.state.status, TravelerEmergencyLoadStatus.notFound);
    expect(cubit.state.emergency, isNull);
    await cubit.close();
  });

  test('offline with no status offers a retry and recovers', () async {
    network.connected = false;
    final cubit = create();

    await cubit.load();
    expect(cubit.state.status, TravelerEmergencyLoadStatus.failure);
    expect(cubit.state.failure, isA<NetworkFailure>());
    expect(repository.getCalls, 0);

    network.connected = true;
    await cubit.load();
    expect(cubit.state.status, TravelerEmergencyLoadStatus.ready);
    await cubit.close();
  });

  test('a silent refresh keeps the instructions if it fails', () async {
    final cubit = create();
    await cubit.load();
    repository.failure = const ServerFailure();

    await cubit.load();

    expect(cubit.state.status, TravelerEmergencyLoadStatus.ready);
    expect(cubit.state.emergency?.immediateInstructions, isNotNull);
    expect(cubit.state.isStale, isTrue);
    await cubit.close();
  });

  test('reconnecting refreshes from REST', () async {
    final cubit = create();
    await cubit.load();
    final before = repository.getCalls;

    network.change(true);
    await pumpEventQueue();

    expect(repository.getCalls, before + 1);
    await cubit.close();
  });

  test('acknowledge records only the receipt time', () async {
    final cubit = create();
    await cubit.load();
    final before = cubit.state.emergency!;

    await cubit.acknowledgeNotice();

    final after = cubit.state.emergency!;
    expect(after.acknowledgedAtUtc, DateTime.utc(2026, 11, 10, 4));
    expect(after.action, before.action);
    expect(after.reasonDetails, before.reasonDetails);
    await cubit.close();
  });

  test('a double acknowledge sends one request', () async {
    final cubit = create();
    await cubit.load();
    repository.gate = Completer<void>();

    final first = cubit.acknowledgeNotice();
    final second = cubit.acknowledgeNotice();
    await pumpEventQueue();
    repository.gate!.complete();
    await Future.wait([first, second]);

    expect(repository.acknowledgeCalls, 1);
    await cubit.close();
  });

  test('an already acknowledged notice is not sent again', () async {
    repository.status = TravelerEmergencyFixture.build(
      acknowledgedAtUtc: DateTime.utc(2026, 11, 10, 3),
    );
    final cubit = create();
    await cubit.load();

    await cubit.acknowledgeNotice();

    expect(repository.acknowledgeCalls, 0);
    await cubit.close();
  });

  test('offline acknowledge is refused and the notice stays', () async {
    final cubit = create();
    await cubit.load();
    network.connected = false;

    await cubit.acknowledgeNotice();

    expect(repository.acknowledgeCalls, 0);
    expect(cubit.state.actionFailure, isA<NetworkFailure>());
    expect(cubit.state.emergency?.isAcknowledged, isFalse);
    await cubit.close();
  });

  test('a failed acknowledge keeps the notice for a retry', () async {
    final cubit = create();
    await cubit.load();
    repository.acknowledgeFailure = const ServerFailure();

    await cubit.acknowledgeNotice();

    expect(cubit.state.actionFailure, isA<ServerFailure>());
    expect(cubit.state.emergency?.isAcknowledged, isFalse);
    expect(cubit.state.isAcknowledging, isFalse);
    await cubit.close();
  });

  test('an older response cannot overwrite a newer acknowledgement', () async {
    final cubit = create();
    await cubit.load();
    repository.gate = Completer<void>();
    final refresh = cubit.load();
    await pumpEventQueue();

    repository.gate = null;
    await cubit.acknowledgeNotice();
    final inFlightGate = repository.firstGate!;
    inFlightGate.complete();
    await refresh;

    expect(cubit.state.emergency?.isAcknowledged, isTrue);
    await cubit.close();
  });
}

final class _FakeRepository implements TravelerEmergencyRepository {
  TravelerEmergencyStatus status = TravelerEmergencyFixture.build();
  Object? failure;
  Object? acknowledgeFailure;
  Completer<void>? _gate;
  Completer<void>? firstGate;
  int getCalls = 0;
  int acknowledgeCalls = 0;

  set gate(Completer<void>? value) {
    _gate = value;
    if (value != null) firstGate = value;
  }

  Completer<void>? get gate => _gate;

  @override
  Future<List<TravelerEmergencyNotice>> getNotices() async => const [];

  @override
  Future<TravelerEmergencyStatus> getStatus(int bookingId) async {
    getCalls++;
    final snapshot = status;
    await _gate?.future;
    final current = failure;
    if (current != null) throw current;
    return snapshot;
  }

  @override
  Future<DateTime> acknowledge(int bookingId) async {
    acknowledgeCalls++;
    await _gate?.future;
    final rejected = acknowledgeFailure;
    if (rejected != null) throw rejected;
    return DateTime.utc(2026, 11, 10, 4);
  }
}
