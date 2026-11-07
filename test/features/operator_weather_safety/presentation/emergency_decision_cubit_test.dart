import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_state.dart';

import '../support/emergency_fixtures.dart';
import '../support/fake_operator_weather_safety_repository.dart';

void main() {
  late FakeOperatorWeatherSafetyRepository repository;
  late FakeNetworkInfo network;
  late int generatedKeys;

  setUp(() {
    repository = FakeOperatorWeatherSafetyRepository()..impacts.add(impact());
    network = FakeNetworkInfo();
    generatedKeys = 0;
  });

  EmergencyDecisionCubit create() => EmergencyDecisionCubit(
    tourId: 12,
    scheduleId: 31,
    getImpact: GetEmergencyImpactUseCase(repository),
    cancelBeforeDeparture: CancelBeforeDepartureUseCase(repository),
    emergencyStop: EmergencyStopTourUseCase(repository),
    networkInfo: network,
    newIdempotencyKey: () => 'key-${++generatedKeys}',
  );

  CancelBeforeDepartureDecision cancelDraft({
    String details = 'Storm warning',
    String version = '',
  }) => CancelBeforeDepartureDecision(
    tourId: 12,
    scheduleId: 31,
    impactVersion: version,
    reason: EmergencyReason.weatherEmergency,
    reasonDetails: details,
  );

  EmergencyStopDecision stopDraft() => EmergencyStopDecision(
    tourId: 12,
    scheduleId: 31,
    impactVersion: '',
    reason: EmergencyReason.safetyIncident,
    reasonDetails: 'Road closed',
    immediateInstructions: 'Stay at the shelter.',
    emergencyContact: '+84 900 000 000',
  );

  Future<EmergencyDecisionCubit> ready() async {
    final cubit = create();
    await cubit.load();
    expect(cubit.state.stage, EmergencyDecisionStage.ready);
    return cubit;
  }

  Future<EmergencyDecisionCubit> awaitingConfirmation() async {
    final cubit = await ready();
    await cubit.prepareConfirmation(cancelDraft());
    expect(cubit.state.stage, EmergencyDecisionStage.awaitingConfirmation);
    return cubit;
  }

  group('fail closed before any decision', () {
    test('offline blocks without calling the Backend', () async {
      network.connected = false;
      final cubit = create();

      await cubit.load();

      expect(cubit.state.stage, EmergencyDecisionStage.blocked);
      expect(cubit.state.blockReason, EmergencyBlockReason.offline);
      expect(repository.impactCalls, 0);
      await cubit.close();
    });

    test('unverified sessions block both actions', () async {
      repository.impacts
        ..clear()
        ..add(impact(hasUnverifiedSessions: true));
      final cubit = create();

      await cubit.load();

      expect(cubit.state.blockReason, EmergencyBlockReason.unverifiedSessions);
      expect(cubit.state.impact, isNotNull, reason: 'impact stays visible');
      await cubit.close();
    });

    test('an unsupported action blocks', () async {
      repository.impacts
        ..clear()
        ..add(impact(action: EmergencyAction.unknown));
      final cubit = create();

      await cubit.load();

      expect(cubit.state.blockReason, EmergencyBlockReason.unsupportedAction);
      await cubit.close();
    });

    test('a malformed response blocks', () async {
      repository.impacts
        ..clear()
        ..add(const UnknownFailure());
      final cubit = create();

      await cubit.load();

      expect(cubit.state.blockReason, EmergencyBlockReason.unavailable);
      expect(cubit.state.impact, isNull);
      await cubit.close();
    });

    test('a foreign schedule is a Safe 404 with no impact', () async {
      repository.impacts
        ..clear()
        ..add(const NotFoundFailure());
      final cubit = create();

      await cubit.load();

      expect(cubit.state.stage, EmergencyDecisionStage.notFound);
      expect(cubit.state.impact, isNull);
      await cubit.close();
    });

    final terminal = {
      EmergencyTourFailureReason.terminal: EmergencyBlockReason.terminal,
      EmergencyTourFailureReason.completed: EmergencyBlockReason.completed,
      EmergencyTourFailureReason.unverifiedSessions:
          EmergencyBlockReason.unverifiedSessions,
    };
    terminal.forEach((reason, block) {
      test('$reason maps to $block', () async {
        repository.impacts
          ..clear()
          ..add(EmergencyTourFailure('x', reason: reason));
        final cubit = create();

        await cubit.load();

        expect(cubit.state.blockReason, block);
        await cubit.close();
      });
    });
  });

  group('confirmation', () {
    test(
      're-fetches the impact and binds the version to the decision',
      () async {
        final cubit = await ready();

        await cubit.prepareConfirmation(cancelDraft());

        expect(repository.impactCalls, 2);
        expect(cubit.state.stage, EmergencyDecisionStage.awaitingConfirmation);
        expect(cubit.state.pendingDecision?.impactVersion, validImpactVersion);
        await cubit.close();
      },
    );

    test('a changed impact refuses confirmation and asks for review', () async {
      final cubit = await ready();
      repository.impacts
        ..clear()
        ..add(impact(version: otherImpactVersion));

      await cubit.prepareConfirmation(cancelDraft());

      expect(cubit.state.stage, EmergencyDecisionStage.ready);
      expect(cubit.state.impactChanged, isTrue);
      expect(cubit.state.impact?.impactVersion, otherImpactVersion);
      expect(cubit.state.pendingDecision, isNull);
      expect(repository.commands, isEmpty);
      await cubit.close();
    });

    test('crossing the start time refuses a Cancel confirmation', () async {
      final cubit = await ready();
      repository.impacts
        ..clear()
        ..add(impact(action: EmergencyAction.emergencyStop));

      await cubit.prepareConfirmation(cancelDraft());

      expect(cubit.state.stage, EmergencyDecisionStage.ready);
      expect(cubit.state.impactChanged, isTrue);
      expect(cubit.state.impact?.action, EmergencyAction.emergencyStop);
      expect(cubit.state.pendingDecision, isNull);
      await cubit.close();
    });

    test('losing the connection while checking blocks', () async {
      final cubit = await ready();
      network.connected = false;

      await cubit.prepareConfirmation(cancelDraft());

      expect(cubit.state.blockReason, EmergencyBlockReason.offline);
      await cubit.close();
    });

    test('unverified sessions found while checking block', () async {
      final cubit = await ready();
      repository.impacts
        ..clear()
        ..add(impact(hasUnverifiedSessions: true));

      await cubit.prepareConfirmation(cancelDraft());

      expect(cubit.state.blockReason, EmergencyBlockReason.unverifiedSessions);
      await cubit.close();
    });

    test('dismissing returns to the form and sends nothing', () async {
      final cubit = await awaitingConfirmation();

      cubit.dismissConfirmation();

      expect(cubit.state.stage, EmergencyDecisionStage.ready);
      expect(repository.commands, isEmpty);
      await cubit.close();
    });
  });

  group('submit', () {
    test('sends the confirmed decision once and reports success', () async {
      repository.commandOutcomes.add(operationResult);
      final cubit = await awaitingConfirmation();

      await cubit.confirm();

      expect(repository.commands, hasLength(1));
      expect(repository.commands.single.key, 'key-1');
      expect(
        repository.commands.single.decision.impactVersion,
        validImpactVersion,
      );
      expect(cubit.state.stage, EmergencyDecisionStage.succeeded);
      expect(cubit.state.result, operationResult);
      await cubit.close();
    });

    test('a double confirm submits once', () async {
      repository
        ..commandOutcomes.add(operationResult)
        ..gate = null;
      final cubit = await awaitingConfirmation();
      repository.gate = Completer<void>();

      final first = cubit.confirm();
      final second = cubit.confirm();
      await pumpEventQueue();
      repository.gate!.complete();
      await Future.wait([first, second]);

      expect(repository.commands, hasLength(1));
      await cubit.close();
    });

    test(
      'the impact is refreshed once more immediately before mutation',
      () async {
        repository.commandOutcomes.add(operationResult);
        final cubit = await awaitingConfirmation();
        final before = repository.impactCalls;

        await cubit.confirm();

        expect(repository.impactCalls, before + 1);
        await cubit.close();
      },
    );

    test('an impact change caught before mutation sends nothing', () async {
      final cubit = await awaitingConfirmation();
      repository.impacts
        ..clear()
        ..add(impact(version: otherImpactVersion));

      await cubit.confirm();

      expect(repository.commands, isEmpty);
      expect(cubit.state.stage, EmergencyDecisionStage.ready);
      expect(cubit.state.impactChanged, isTrue);
      await cubit.close();
    });

    test('crossing the start time before mutation sends nothing', () async {
      final cubit = await awaitingConfirmation();
      repository.impacts
        ..clear()
        ..add(impact(action: EmergencyAction.emergencyStop));

      await cubit.confirm();

      expect(repository.commands, isEmpty);
      expect(cubit.state.impact?.action, EmergencyAction.emergencyStop);
      expect(cubit.state.impactChanged, isTrue);
      await cubit.close();
    });

    test(
      'going offline before mutation sends nothing and queues nothing',
      () async {
        final cubit = await awaitingConfirmation();
        network.connected = false;

        await cubit.confirm();

        expect(repository.commands, isEmpty);
        expect(cubit.state.blockReason, EmergencyBlockReason.offline);
        network.connected = true;
        await pumpEventQueue();
        expect(repository.commands, isEmpty);
        await cubit.close();
      },
    );

    test(
      'a stale 409 reloads the impact and requires a new confirmation',
      () async {
        repository.commandOutcomes.add(
          const EmergencyTourFailure(
            'changed',
            reason: EmergencyTourFailureReason.staleImpact,
          ),
        );
        final cubit = await awaitingConfirmation();
        repository.impacts
          ..clear()
          ..addAll([impact(), impact(version: otherImpactVersion)]);

        await cubit.confirm();

        expect(cubit.state.stage, EmergencyDecisionStage.ready);
        expect(cubit.state.impactChanged, isTrue);
        expect(cubit.state.impact?.impactVersion, otherImpactVersion);
        expect(cubit.state.pendingDecision, isNull);
        await cubit.close();
      },
    );

    test(
      'a wrong action window reloads so the Backend action is used',
      () async {
        repository.commandOutcomes.add(
          const EmergencyTourFailure(
            'window',
            reason: EmergencyTourFailureReason.wrongActionWindow,
          ),
        );
        final cubit = await awaitingConfirmation();
        repository.impacts
          ..clear()
          ..addAll([impact(), impact(action: EmergencyAction.emergencyStop)]);

        await cubit.confirm();

        expect(cubit.state.impact?.action, EmergencyAction.emergencyStop);
        expect(cubit.state.stage, EmergencyDecisionStage.ready);
        await cubit.close();
      },
    );

    test('a terminal duplicate is shown as already decided', () async {
      repository.commandOutcomes.add(
        const EmergencyTourFailure(
          'terminal',
          reason: EmergencyTourFailureReason.terminal,
        ),
      );
      final cubit = await awaitingConfirmation();

      await cubit.confirm();

      expect(cubit.state.blockReason, EmergencyBlockReason.terminal);
      await cubit.close();
    });

    test('a validation failure returns to the form with its message', () async {
      repository.commandOutcomes.add(const ValidationFailure('Bad input'));
      final cubit = await awaitingConfirmation();

      await cubit.confirm();

      expect(cubit.state.stage, EmergencyDecisionStage.ready);
      expect(cubit.state.failure, const ValidationFailure('Bad input'));
      await cubit.close();
    });

    test('a foreign schedule during submit is a Safe 404', () async {
      repository.commandOutcomes.add(const NotFoundFailure());
      final cubit = await awaitingConfirmation();

      await cubit.confirm();

      expect(cubit.state.stage, EmergencyDecisionStage.notFound);
      expect(cubit.state.impact, isNull);
      await cubit.close();
    });
  });

  group('connectivity and resume', () {
    test('losing the connection blocks the form at once', () async {
      final cubit = await ready();

      network.change(false);
      await pumpEventQueue();

      expect(cubit.state.blockReason, EmergencyBlockReason.offline);
      await cubit.close();
    });

    test('reconnecting reloads the impact before enabling the form', () async {
      final cubit = await ready();
      network.change(false);
      await pumpEventQueue();
      final before = repository.impactCalls;

      network.change(true);
      await pumpEventQueue();

      expect(repository.impactCalls, before + 1);
      expect(cubit.state.stage, EmergencyDecisionStage.ready);
      await cubit.close();
    });

    test('connectivity changes never disturb a submit in progress', () async {
      repository.commandOutcomes.add(operationResult);
      final cubit = await awaitingConfirmation();
      repository.gate = Completer<void>();
      final submitting = cubit.confirm();
      await pumpEventQueue();

      network.change(false);
      await pumpEventQueue();
      expect(cubit.state.stage, EmergencyDecisionStage.submitting);

      network.change(true);
      repository.gate!.complete();
      await submitting;
      expect(cubit.state.stage, EmergencyDecisionStage.succeeded);
      await cubit.close();
    });

    test('resuming re-reads the impact and flags a change', () async {
      final cubit = await ready();
      repository.impacts
        ..clear()
        ..add(impact(version: otherImpactVersion));

      await cubit.refreshOnResume();

      expect(cubit.state.impactChanged, isTrue);
      expect(cubit.state.impact?.impactVersion, otherImpactVersion);
      await cubit.close();
    });

    test('resuming leaves a confirmation and a final result alone', () async {
      repository.commandOutcomes.add(operationResult);
      final cubit = await awaitingConfirmation();
      final before = repository.impactCalls;

      await cubit.refreshOnResume();
      expect(repository.impactCalls, before);

      await cubit.confirm();
      final after = repository.impactCalls;
      await cubit.refreshOnResume();
      expect(repository.impactCalls, after);
      expect(cubit.state.stage, EmergencyDecisionStage.succeeded);
      await cubit.close();
    });
  });

  group('idempotency', () {
    test(
      'an ambiguous timeout keeps the intent for an identical retry',
      () async {
        repository.commandOutcomes.addAll([
          const NetworkFailure(),
          operationResult,
        ]);
        final cubit = await awaitingConfirmation();

        await cubit.confirm();
        expect(cubit.state.stage, EmergencyDecisionStage.ambiguous);
        final impactCalls = repository.impactCalls;

        await cubit.retry();

        expect(repository.commands, hasLength(2));
        expect(repository.commands[0].key, repository.commands[1].key);
        expect(
          repository.commands[0].decision,
          repository.commands[1].decision,
        );
        expect(
          repository.impactCalls,
          impactCalls,
          reason:
              'after a possibly committed stop the impact endpoint answers 409, '
              'so the retry must replay the frozen request',
        );
        expect(cubit.state.stage, EmergencyDecisionStage.succeeded);
        await cubit.close();
      },
    );

    test('nothing retries on its own', () async {
      repository.commandOutcomes.add(const NetworkFailure());
      final cubit = await awaitingConfirmation();

      await cubit.confirm();
      await pumpEventQueue();

      expect(repository.commands, hasLength(1));
      await cubit.close();
    });

    test('a server error is also treated as ambiguous', () async {
      repository.commandOutcomes.add(const ServerFailure());
      final cubit = await awaitingConfirmation();

      await cubit.confirm();

      expect(cubit.state.stage, EmergencyDecisionStage.ambiguous);
      await cubit.close();
    });

    test('offline retry sends nothing and stays ambiguous', () async {
      repository.commandOutcomes.add(const NetworkFailure());
      final cubit = await awaitingConfirmation();
      await cubit.confirm();
      network.connected = false;

      await cubit.retry();

      expect(repository.commands, hasLength(1));
      expect(cubit.state.stage, EmergencyDecisionStage.ambiguous);
      await cubit.close();
    });

    test('the same payload confirmed again reuses the key', () async {
      repository.commandOutcomes.addAll([
        const ValidationFailure('Bad input'),
        operationResult,
      ]);
      final cubit = await awaitingConfirmation();
      await cubit.confirm();

      await cubit.prepareConfirmation(cancelDraft());
      await cubit.confirm();

      expect(repository.commands[0].key, repository.commands[1].key);
      await cubit.close();
    });

    test('a changed payload is a new intent with a new key', () async {
      repository.commandOutcomes.addAll([
        const ValidationFailure('Bad input'),
        operationResult,
      ]);
      final cubit = await awaitingConfirmation();
      await cubit.confirm();

      await cubit.prepareConfirmation(cancelDraft(details: 'Flooded road'));
      await cubit.confirm();

      expect(repository.commands[0].key, isNot(repository.commands[1].key));
      await cubit.close();
    });

    test('a changed impact version is a new intent', () async {
      repository.commandOutcomes.addAll([
        const EmergencyTourFailure(
          'changed',
          reason: EmergencyTourFailureReason.staleImpact,
        ),
        operationResult,
      ]);
      final cubit = await awaitingConfirmation();
      repository.impacts
        ..clear()
        ..addAll([impact(), impact(version: otherImpactVersion)]);
      await cubit.confirm();

      await cubit.prepareConfirmation(cancelDraft());
      await cubit.confirm();

      expect(repository.commands[0].key, isNot(repository.commands[1].key));
      await cubit.close();
    });

    test('a payload mismatch abandons the key', () async {
      repository.commandOutcomes.addAll([
        const EmergencyTourFailure(
          'mismatch',
          reason: EmergencyTourFailureReason.idempotencyMismatch,
        ),
        operationResult,
      ]);
      final cubit = await awaitingConfirmation();
      await cubit.confirm();

      await cubit.prepareConfirmation(cancelDraft());
      await cubit.confirm();

      expect(repository.commands[0].key, isNot(repository.commands[1].key));
      await cubit.close();
    });
  });

  group('password handling', () {
    Future<EmergencyDecisionCubit> stopAwaitingConfirmation() async {
      repository.impacts
        ..clear()
        ..add(impact(action: EmergencyAction.emergencyStop));
      final cubit = await ready();
      await cubit.prepareConfirmation(stopDraft());
      return cubit;
    }

    test('a stop without a password is not sent', () async {
      final cubit = await stopAwaitingConfirmation();

      await cubit.confirm();

      expect(repository.commands, isEmpty);
      expect(cubit.state.failure, isA<ValidationFailure>());
      await cubit.close();
    });

    test(
      'a wrong password keeps the form and reports the safe failure',
      () async {
        repository.commandOutcomes.add(
          const EmergencyTourFailure(
            'unverified',
            reason: EmergencyTourFailureReason.wrongPassword,
          ),
        );
        final cubit = await stopAwaitingConfirmation();

        await cubit.confirm(currentPassword: 'transient-value');

        expect(cubit.state.stage, EmergencyDecisionStage.ready);
        expect(cubit.state.isPasswordRejected, isTrue);
        await cubit.close();
      },
    );

    test('a retry after a wrong password reuses the key', () async {
      repository.commandOutcomes.addAll([
        const EmergencyTourFailure(
          'unverified',
          reason: EmergencyTourFailureReason.wrongPassword,
        ),
        operationResult,
      ]);
      final cubit = await stopAwaitingConfirmation();
      await cubit.confirm(currentPassword: 'wrong-value');

      await cubit.prepareConfirmation(stopDraft());
      await cubit.confirm(currentPassword: 'right-value');

      expect(repository.commands[0].key, repository.commands[1].key);
      await cubit.close();
    });

    test('no state ever contains the password', () async {
      repository.commandOutcomes.addAll([
        const NetworkFailure(),
        operationResult,
      ]);
      final cubit = await stopAwaitingConfirmation();
      final dumps = <String>[];
      final subscription = cubit.stream.listen(
        (state) => dumps.add('$state ${state.props}'),
      );

      await cubit.confirm(currentPassword: 'transient-value');
      await cubit.retry(currentPassword: 'transient-value');
      await pumpEventQueue();

      expect(dumps, isNotEmpty);
      expect(dumps.join(), isNot(contains('transient-value')));
      await subscription.cancel();
      await cubit.close();
    });
  });
}
