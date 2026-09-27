import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/repositories/password_recovery_repository.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_state.dart';

void main() {
  group('PasswordRecoveryCubit', () {
    test('request success is accepted with neutral delivery copy', () async {
      final repository = _FakePasswordRecoveryRepository();
      final ticks = StreamController<int>();
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await ticks.close();
      });

      final result = await cubit.requestReset('  User@Example.COM ');

      expect(result, isTrue);
      expect(repository.requestedEmails, ['user@example.com']);
      expect(cubit.state.status, PasswordRecoveryStatus.requestAccepted);
      expect(cubit.state.normalizedEmail, 'user@example.com');
      expect(cubit.state.cooldownSeconds, 60);
      expect(
        cubit.state.feedbackMessage,
        'If a reset code was sent, check your email.',
      );
      expect(cubit.state.feedbackMessage, isNot(contains('successfully')));
      expect(cubit.state.feedbackMessage, isNot('Code sent successfully'));
    });

    test('request failure stays retryable with safe field errors', () async {
      final repository = _FakePasswordRecoveryRepository(
        requestError: const ValidationFailure(
          'Unable to complete this request. Please check the highlighted fields.',
          fieldErrors: {
            'email': ['Enter a valid email address.'],
          },
        ),
      );
      final cubit = PasswordRecoveryCubit(repository);
      addTearDown(cubit.close);

      final firstResult = await cubit.requestReset('invalid');

      expect(firstResult, isFalse);
      expect(cubit.state.status, PasswordRecoveryStatus.failure);
      expect(cubit.state.errorMessage, contains('highlighted fields'));
      expect(cubit.state.fieldErrors['email'], [
        'Enter a valid email address.',
      ]);

      repository.requestError = null;
      final retryResult = await cubit.requestReset('User@Example.com');

      expect(retryResult, isTrue);
      expect(repository.requestedEmails.last, 'user@example.com');
    });

    test('duplicate request is ignored while the first is pending', () async {
      final pending = Completer<void>();
      final repository = _FakePasswordRecoveryRepository(
        requestCompleter: pending,
      );
      final cubit = PasswordRecoveryCubit(repository);
      addTearDown(cubit.close);

      final first = cubit.requestReset('user@example.com');
      await Future<void>.delayed(Duration.zero);
      final duplicate = await cubit.requestReset('user@example.com');

      expect(duplicate, isFalse);
      expect(repository.requestedEmails, ['user@example.com']);

      pending.complete();
      expect(await first, isTrue);
    });

    test(
      'pending request completes safely after the cubit is closed',
      () async {
        final pending = Completer<void>();
        final repository = _FakePasswordRecoveryRepository(
          requestCompleter: pending,
        );
        final cubit = PasswordRecoveryCubit(repository);

        final request = cubit.requestReset('user@example.com');
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        pending.complete();

        await expectLater(request, completion(isFalse));
      },
    );

    test('resend waits for cooldown and restarts it with neutral copy', () async {
      final ticks = StreamController<int>.broadcast();
      final repository = _FakePasswordRecoveryRepository();
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await ticks.close();
      });

      await cubit.requestReset('user@example.com');
      expect(await cubit.resend(), isFalse);
      expect(repository.requestedEmails, ['user@example.com']);

      ticks.add(0);
      await Future<void>.delayed(Duration.zero);

      expect(await cubit.resend(), isTrue);
      expect(repository.requestedEmails, [
        'user@example.com',
        'user@example.com',
      ]);
      expect(cubit.state.cooldownSeconds, 60);
      expect(
        cubit.state.feedbackMessage,
        'If a new reset code was sent, any previous code may no longer be valid.',
      );
      expect(cubit.state.feedbackMessage, isNot(contains('successfully')));
    });

    test('pending resend completes safely after the cubit is closed', () async {
      final pending = Completer<void>();
      final ticks = StreamController<int>.broadcast();
      final repository = _FakePasswordRecoveryRepository();
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(ticks.close);
      await cubit.requestReset('user@example.com');
      ticks.add(0);
      await Future<void>.delayed(Duration.zero);
      repository.requestCompleter = pending;

      final resend = cubit.resend();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      pending.complete();

      await expectLater(resend, completion(isFalse));
    });

    test('rate-limited resend stays retryable and restarts cooldown', () async {
      final ticks = StreamController<int>.broadcast();
      final repository = _FakePasswordRecoveryRepository();
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await ticks.close();
      });

      await cubit.requestReset('user@example.com');
      ticks.add(0);
      await Future<void>.delayed(Duration.zero);
      repository.requestError = const RateLimitFailure(
        'Too many reset attempts. Please wait and try again.',
      );

      expect(await cubit.resend(), isFalse);
      expect(cubit.state.status, PasswordRecoveryStatus.failure);
      expect(cubit.state.normalizedEmail, 'user@example.com');
      expect(cubit.state.cooldownSeconds, 60);
      expect(
        cubit.state.errorMessage,
        'Too many reset attempts. Please wait and try again.',
      );
    });

    test('confirm forwards exact values and clears recovery state', () async {
      final ticks = StreamController<int>();
      final repository = _FakePasswordRecoveryRepository();
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await ticks.close();
      });
      await cubit.requestReset('User@Example.com');

      final result = await cubit.confirmReset(
        code: '012345',
        newPassword: 'NewPassword123!',
      );

      expect(result, isTrue);
      expect(repository.confirmed, (
        email: 'user@example.com',
        code: '012345',
        newPassword: 'NewPassword123!',
      ));
      expect(cubit.state.status, PasswordRecoveryStatus.success);
      expect(cubit.state.normalizedEmail, isNull);
      expect(cubit.state.cooldownSeconds, 0);
      expect(
        cubit.state.feedbackMessage,
        'Your password has been reset. Sign in with your new password.',
      );
    });

    test('cooldown ticks cannot interrupt a pending confirmation', () async {
      final ticks = StreamController<int>.broadcast();
      final confirmation = Completer<void>();
      final repository = _FakePasswordRecoveryRepository(
        confirmCompleter: confirmation,
      );
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await ticks.close();
      });
      await cubit.requestReset('user@example.com');

      final pending = cubit.confirmReset(
        code: '012345',
        newPassword: 'NewPassword123!',
      );
      await Future<void>.delayed(Duration.zero);
      ticks.add(59);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PasswordRecoveryStatus.confirming);
      expect(
        await cubit.confirmReset(
          code: '012345',
          newPassword: 'NewPassword123!',
        ),
        isFalse,
      );

      confirmation.complete();
      expect(await pending, isTrue);
    });

    test(
      'pending confirmation completes safely after the cubit is closed',
      () async {
        final pending = Completer<void>();
        final repository = _FakePasswordRecoveryRepository(
          confirmCompleter: pending,
        );
        final cubit = PasswordRecoveryCubit(
          repository,
          cooldownStream: (_) => const Stream<int>.empty(),
        );
        await cubit.requestReset('user@example.com');

        final confirmation = cubit.confirmReset(
          code: '012345',
          newPassword: 'NewPassword123!',
        );
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        pending.complete();

        await expectLater(confirmation, completion(isFalse));
      },
    );

    test('cooldown ticks preserve a confirm failure and its message', () async {
      final ticks = StreamController<int>.broadcast();
      final repository = _FakePasswordRecoveryRepository();
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => ticks.stream,
      );
      addTearDown(() async {
        await cubit.close();
        await ticks.close();
      });
      await cubit.requestReset('user@example.com');
      repository.confirmError = const ValidationFailure(
        'The reset code is invalid or no longer usable. Request a new code and try again.',
      );
      await cubit.confirmReset(code: '000000', newPassword: 'NewPassword123!');

      ticks.add(59);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PasswordRecoveryStatus.failure);
      expect(cubit.state.errorMessage, contains('invalid or no longer usable'));
      expect(cubit.state.cooldownSeconds, 59);
    });

    test(
      'confirm failure preserves the step and allows an explicit retry',
      () async {
        final repository = _FakePasswordRecoveryRepository();
        final cubit = PasswordRecoveryCubit(repository);
        addTearDown(cubit.close);
        await cubit.requestReset('user@example.com');
        repository.confirmError = const ValidationFailure(
          'The reset code is invalid or no longer usable. Request a new code and try again.',
        );

        final failed = await cubit.confirmReset(
          code: '000000',
          newPassword: 'NewPassword123!',
        );

        expect(failed, isFalse);
        expect(cubit.state.status, PasswordRecoveryStatus.failure);
        expect(cubit.state.normalizedEmail, 'user@example.com');
        expect(
          cubit.state.errorMessage,
          contains('invalid or no longer usable'),
        );

        repository.confirmError = null;
        final retried = await cubit.confirmReset(
          code: '012345',
          newPassword: 'NewPassword123!',
        );

        expect(retried, isTrue);
        expect(cubit.state.status, PasswordRecoveryStatus.success);
      },
    );
  });
}

final class _FakePasswordRecoveryRepository
    implements PasswordRecoveryRepository {
  _FakePasswordRecoveryRepository({
    this.requestError,
    this.requestCompleter,
    this.confirmCompleter,
  });

  Object? requestError;
  Object? confirmError;
  Completer<void>? requestCompleter;
  final Completer<void>? confirmCompleter;
  final requestedEmails = <String>[];
  ({String email, String code, String newPassword})? confirmed;

  @override
  Future<void> requestPasswordReset(String email) async {
    requestedEmails.add(email);
    await requestCompleter?.future;
    if (requestError != null) throw requestError!;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    confirmed = (email: email, code: code, newPassword: newPassword);
    await confirmCompleter?.future;
    if (confirmError != null) throw confirmError!;
  }
}
