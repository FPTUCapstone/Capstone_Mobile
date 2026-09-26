import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/repositories/password_recovery_repository.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_state.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/pages/password_recovery_page.dart';

void main() {
  const responsiveSizes = <Size>[
    Size(320, 568),
    Size(360, 800),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in responsiveSizes) {
    testWidgets(
      'remains usable at ${size.width.toInt()}px with large text and keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        final repository = _FakePasswordRecoveryRepository();
        final cubit = PasswordRecoveryCubit(
          repository,
          cooldownStream: (_) => const Stream<int>.empty(),
        );
        addTearDown(cubit.close);
        await tester.pumpWidget(_responsiveTestApp(cubit));

        final emailField = find.widgetWithText(TextFormField, 'Email address');
        await tester.showKeyboard(emailField);
        await tester.enterText(emailField, 'user@example.com');
        await tester.ensureVisible(find.text('Send Reset Code'));
        await tester.tap(find.text('Send Reset Code'));
        await tester.pump();
        await tester.pump();

        final passwordField = find.widgetWithText(
          TextFormField,
          'New password',
        );
        await tester.ensureVisible(passwordField);
        await tester.showKeyboard(passwordField);
        await tester.pump();

        expect(find.text('Reset your password'), findsOneWidget);
        expect(find.text('Reset Password'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('request step validates email then shows neutral reset form', (
    tester,
  ) async {
    final repository = _FakePasswordRecoveryRepository();
    final cubit = PasswordRecoveryCubit(
      repository,
      cooldownStream: (_) => const Stream<int>.empty(),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));

    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Send Reset Code'), findsOneWidget);

    await tester.tap(find.text('Send Reset Code'));
    await tester.pump();
    expect(find.text('Email is required.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      '  User@Example.COM ',
    );
    await tester.tap(find.text('Send Reset Code'));
    await tester.pump();
    await tester.pump();

    expect(repository.requestedEmails, ['user@example.com']);
    expect(find.text('Reset your password'), findsOneWidget);
    expect(
      find.text('If a reset code was sent, check your email.'),
      findsOneWidget,
    );
    expect(find.text('Code sent successfully'), findsNothing);
    expect(find.text('Reset code'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('request form stays visible until the backend accepts', (
    tester,
  ) async {
    final requestGate = Completer<void>();
    final repository = _FakePasswordRecoveryRepository(
      requestGate: requestGate,
    );
    final cubit = PasswordRecoveryCubit(
      repository,
      cooldownStream: (_) => const Stream<int>.empty(),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.tap(find.text('Send Reset Code'));
    await tester.pump();

    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Reset your password'), findsNothing);
    expect(find.text('Reset code'), findsNothing);

    requestGate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets(
    'editing email clears its backend error and allows another request',
    (tester) async {
      const emailError = 'Invalid email format.';
      final repository = _FakePasswordRecoveryRepository(
        requestError: const ValidationFailure(
          'Unable to complete this request. Please check the highlighted fields.',
          fieldErrors: {
            'email': [emailError],
          },
        ),
      );
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => const Stream<int>.empty(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(_testApp(cubit));

      final emailField = find.widgetWithText(TextFormField, 'Email address');
      await tester.enterText(emailField, 'first@example.com');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pump();
      await tester.pump();

      expect(find.text(emailError), findsOneWidget);
      expect(repository.requestedEmails, ['first@example.com']);

      repository.requestError = null;
      await tester.enterText(emailField, 'second@example.com');
      await tester.pump();

      expect(find.text(emailError), findsNothing);

      await tester.tap(find.text('Send Reset Code'));
      await tester.pump();
      await tester.pump();

      expect(repository.requestedEmails, [
        'first@example.com',
        'second@example.com',
      ]);
      expect(find.text('Reset your password'), findsOneWidget);
    },
  );

  testWidgets('reset form rejects non-ASCII OTP and invalid passwords', (
    tester,
  ) async {
    final repository = _FakePasswordRecoveryRepository();
    final cubit = PasswordRecoveryCubit(
      repository,
      cooldownStream: (_) => const Stream<int>.empty(),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));
    await _openResetForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reset code'),
      '١٢٣٤٥٦',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'weak',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different',
    );
    await tester.tap(find.text('Reset Password'));
    await tester.pump();

    expect(find.text('Enter exactly 6 ASCII digits.'), findsOneWidget);
    expect(
      find.text('Password must be between 8 and 72 characters.'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(repository.confirmed, isNull);
  });

  testWidgets('successful reset returns to login without authenticating', (
    tester,
  ) async {
    final repository = _FakePasswordRecoveryRepository();
    final cubit = PasswordRecoveryCubit(
      repository,
      cooldownStream: (_) => const Stream<int>.empty(),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.forgotPassword,
      routes: [
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, _) => BlocProvider<PasswordRecoveryCubit>.value(
            value: cubit,
            child: const PasswordRecoveryPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                const Text('Login destination'),
                Text(state.extra as String? ?? ''),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await cubit.close();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _openResetForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reset code'),
      '012345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewPassword123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'NewPassword123!',
    );
    final completed = cubit.stream.firstWhere(
      (state) => state.status == PasswordRecoveryStatus.success,
    );
    await tester.tap(find.text('Reset Password'));
    await tester.pump();
    await completed;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.confirmed, (
      email: 'user@example.com',
      code: '012345',
      newPassword: 'NewPassword123!',
    ));
    expect(cubit.state.status, PasswordRecoveryStatus.success);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.login,
    );
    expect(find.text('Login destination'), findsOneWidget);
    expect(
      find.text(
        'Your password has been reset. Sign in with your new password.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('resend is disabled during cooldown and uses neutral feedback', (
    tester,
  ) async {
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
    await tester.pumpWidget(_testApp(cubit));
    await _openResetForm(tester);

    final disabled = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Resend code (60s)'),
    );
    expect(disabled.onPressed, isNull);

    final ready = cubit.stream.firstWhere(
      (state) => state.cooldownSeconds == 0,
    );
    ticks.add(0);
    await tester.pump();
    await ready;
    await tester.pump();
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    await tester.pump();

    expect(repository.requestedEmails, [
      'user@example.com',
      'user@example.com',
    ]);
    expect(
      find.text(
        'If a new reset code was sent, any previous code may no longer be valid.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('backend rejection keeps the reset form and entered values', (
    tester,
  ) async {
    const safeError =
        'The reset code is invalid or no longer usable. Request a new code and try again.';
    final repository = _FakePasswordRecoveryRepository(
      confirmError: const ValidationFailure(safeError),
    );
    final cubit = PasswordRecoveryCubit(
      repository,
      cooldownStream: (_) => const Stream<int>.empty(),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));
    await _openResetForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reset code'),
      '012345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewPassword123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'NewPassword123!',
    );
    await tester.tap(find.text('Reset Password'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text(safeError), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Reset code'),
          )
          .controller
          ?.text,
      '012345',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'New password'),
          )
          .controller
          ?.text,
      'NewPassword123!',
    );
  });

  testWidgets(
    'editing password clears its backend error and allows another confirmation',
    (tester) async {
      const passwordError = 'Password does not meet the required policy.';
      final repository = _FakePasswordRecoveryRepository(
        confirmError: const ValidationFailure(
          'Unable to complete this request. Please check the highlighted fields.',
          fieldErrors: {
            'newPassword': [passwordError],
          },
        ),
      );
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => const Stream<int>.empty(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(_testApp(cubit));
      await _openResetForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reset code'),
        '012345',
      );
      final passwordField = find.widgetWithText(TextFormField, 'New password');
      await tester.enterText(passwordField, 'FirstPassword123!');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'FirstPassword123!',
      );
      await tester.tap(find.text('Reset Password'));
      await tester.pump();
      await tester.pump();

      expect(find.text(passwordError), findsOneWidget);
      expect(repository.confirmed, (
        email: 'user@example.com',
        code: '012345',
        newPassword: 'FirstPassword123!',
      ));

      repository.confirmError = const ValidationFailure(
        'The reset code is invalid or no longer usable.',
      );
      await tester.enterText(passwordField, 'SecondPassword123!');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'SecondPassword123!',
      );
      await tester.pump();

      expect(find.text(passwordError), findsNothing);

      await tester.tap(find.text('Reset Password'));
      await tester.pump();
      await tester.pump();

      expect(repository.confirmedRequests, [
        (
          email: 'user@example.com',
          code: '012345',
          newPassword: 'FirstPassword123!',
        ),
        (
          email: 'user@example.com',
          code: '012345',
          newPassword: 'SecondPassword123!',
        ),
      ]);
    },
  );

  testWidgets(
    'editing reset code clears its backend error and allows another confirmation',
    (tester) async {
      const codeError = 'Invalid verification code.';
      final repository = _FakePasswordRecoveryRepository(
        confirmError: const ValidationFailure(
          'Unable to complete this request. Please check the highlighted fields.',
          fieldErrors: {
            'code': [codeError],
          },
        ),
      );
      final cubit = PasswordRecoveryCubit(
        repository,
        cooldownStream: (_) => const Stream<int>.empty(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(_testApp(cubit));
      await _openResetForm(tester);

      final codeField = find.widgetWithText(TextFormField, 'Reset code');
      await tester.enterText(codeField, '000000');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'NewPassword123!',
      );
      await tester.tap(find.text('Reset Password'));
      await tester.pump();
      await tester.pump();

      expect(find.text(codeError), findsOneWidget);

      repository.confirmError = const InvalidResetCredentialFailure();
      await tester.enterText(codeField, '012345');
      await tester.pump();

      expect(find.text(codeError), findsNothing);

      await tester.tap(find.text('Reset Password'));
      await tester.pump();
      await tester.pump();

      expect(repository.confirmedRequests, [
        (
          email: 'user@example.com',
          code: '000000',
          newPassword: 'NewPassword123!',
        ),
        (
          email: 'user@example.com',
          code: '012345',
          newPassword: 'NewPassword123!',
        ),
      ]);
    },
  );

  testWidgets('Back disposes a pending request without an async exception', (
    tester,
  ) async {
    final requestGate = Completer<void>();
    final repository = _FakePasswordRecoveryRepository(
      requestGate: requestGate,
    );
    late PasswordRecoveryCubit cubit;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, _) => const Scaffold(body: Text('Previous page')),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, _) => BlocProvider<PasswordRecoveryCubit>(
            create: (_) => cubit = PasswordRecoveryCubit(
              repository,
              cooldownStream: (_) => const Stream<int>.empty(),
            ),
            child: const PasswordRecoveryPage(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push<void>(AppRoutes.forgotPassword));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.tap(find.text('Send Reset Code'));
    await tester.pump();
    expect(repository.requestedEmails, ['user@example.com']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Previous page'), findsOneWidget);
    expect(cubit.isClosed, isTrue);

    requestGate.complete();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _openResetForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    'user@example.com',
  );
  await tester.tap(find.text('Send Reset Code'));
  await tester.pump();
  await tester.pump();
}

Widget _testApp(PasswordRecoveryCubit cubit) {
  return MaterialApp(
    home: BlocProvider<PasswordRecoveryCubit>.value(
      value: cubit,
      child: const PasswordRecoveryPage(),
    ),
  );
}

Widget _responsiveTestApp(PasswordRecoveryCubit cubit) {
  return MaterialApp(
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      );
    },
    home: BlocProvider<PasswordRecoveryCubit>.value(
      value: cubit,
      child: const PasswordRecoveryPage(),
    ),
  );
}

final class _FakePasswordRecoveryRepository
    implements PasswordRecoveryRepository {
  _FakePasswordRecoveryRepository({
    this.requestGate,
    this.requestError,
    this.confirmError,
  });

  final Completer<void>? requestGate;
  Failure? requestError;
  Failure? confirmError;
  final requestedEmails = <String>[];
  final confirmedRequests =
      <({String email, String code, String newPassword})>[];
  ({String email, String code, String newPassword})? confirmed;

  @override
  Future<void> requestPasswordReset(String email) async {
    requestedEmails.add(email);
    await requestGate?.future;
    if (requestError case final error?) throw error;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    confirmed = (email: email, code: code, newPassword: newPassword);
    confirmedRequests.add((email: email, code: code, newPassword: newPassword));
    if (confirmError case final error?) throw error;
  }
}
