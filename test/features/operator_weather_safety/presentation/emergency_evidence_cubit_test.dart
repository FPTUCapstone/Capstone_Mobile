import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_evidence_cubit.dart';

import '../support/fake_operator_weather_safety_repository.dart';

void main() {
  late FakeOperatorWeatherSafetyRepository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = FakeOperatorWeatherSafetyRepository();
    network = FakeNetworkInfo();
  });

  EmergencyEvidenceCubit create() => EmergencyEvidenceCubit(
    tourId: 12,
    scheduleId: 31,
    save: SaveEmergencyEvidenceUseCase(repository),
    withdraw: WithdrawEmergencyEvidenceUseCase(repository),
    read: GetEmergencyEvidenceUseCase(repository),
    networkInfo: network,
  );

  const evidence = EmergencyEvidence(url: 'https://authority.example/notice');

  test('load shows the current evidence for editing', () async {
    repository.currentEvidence = const EmergencyEvidenceSnapshot(
      evidence: EmergencyEvidence(reference: 'REF-1'),
      version: 'v1',
    );
    final cubit = create();

    await cubit.load();

    expect(cubit.state.current?.evidence.reference, 'REF-1');
    await cubit.close();
  });

  test('a save carries the version read and reloads afterwards', () async {
    repository.currentEvidence = const EmergencyEvidenceSnapshot(
      evidence: EmergencyEvidence(reference: 'REF-1'),
      version: 'v1',
    );
    final cubit = create();
    await cubit.load();

    await cubit.saveEvidence(evidence);

    expect(repository.lastExpectedVersion, 'v1');
    expect(repository.evidenceReads, 2);
    await cubit.close();
  });

  test('a stale save reloads the newer evidence and says so', () async {
    repository
      ..currentEvidence = const EmergencyEvidenceSnapshot(
        evidence: EmergencyEvidence(reference: 'NEWER'),
        version: 'v2',
      )
      ..failure = null
      ..saveFailure = const EmergencyTourFailure(
        'changed',
        reason: EmergencyTourFailureReason.staleEvidence,
      );
    final cubit = create();
    await cubit.load();

    await cubit.saveEvidence(evidence);

    expect(cubit.state.status, EmergencyEvidenceStatus.failure);
    expect(cubit.state.current?.version, 'v2');
    await cubit.close();
  });

  test('an edit is refused until the current evidence was read', () async {
    repository.failure = const ServerFailure();
    final cubit = create();
    await cubit.load();
    repository.failure = null;

    await cubit.saveEvidence(evidence);
    await cubit.withdrawEvidence();

    expect(repository.evidenceCalls, isEmpty);
    expect(cubit.state.current, isNull);
    await cubit.close();
  });

  test('withdraw is based on the version read', () async {
    repository.currentEvidence = const EmergencyEvidenceSnapshot(
      evidence: EmergencyEvidence(reference: 'REF-1'),
      version: 'v1',
    );
    final cubit = create();
    await cubit.load();

    await cubit.withdrawEvidence();

    expect(repository.lastExpectedVersion, 'v1');
    await cubit.close();
  });

  test('saving reports success', () async {
    final cubit = create();
    await cubit.load();

    await cubit.saveEvidence(evidence);

    expect(repository.evidenceCalls.single, evidence);
    expect(cubit.state.status, EmergencyEvidenceStatus.saved);
    await cubit.close();
  });

  test('withdrawing sends no values and reports it', () async {
    final cubit = create();
    await cubit.load();

    await cubit.withdrawEvidence();

    expect(repository.evidenceCalls.single, isNull);
    expect(cubit.state.status, EmergencyEvidenceStatus.withdrawn);
    await cubit.close();
  });

  test('a double submit sends one request', () async {
    final cubit = create();
    await cubit.load();
    repository.gate = Completer<void>();

    final first = cubit.saveEvidence(evidence);
    final second = cubit.saveEvidence(evidence);
    await pumpEventQueue();
    repository.gate!.complete();
    await Future.wait([first, second]);

    expect(repository.evidenceCalls, hasLength(1));
    await cubit.close();
  });

  test('offline sends nothing', () async {
    final cubit = create();
    await cubit.load();
    network.connected = false;

    await cubit.saveEvidence(evidence);

    expect(repository.evidenceCalls, isEmpty);
    expect(cubit.state.status, EmergencyEvidenceStatus.failure);
    expect(cubit.state.failure, isA<NetworkFailure>());
    await cubit.close();
  });

  test('a Backend rejection is reported', () async {
    final cubit = create();
    await cubit.load();
    repository.failure = const NotFoundFailure();

    await cubit.saveEvidence(evidence);

    expect(cubit.state.status, EmergencyEvidenceStatus.failure);
    expect(cubit.state.failure, isA<NotFoundFailure>());
    await cubit.close();
  });
}
