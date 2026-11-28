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

        final emailField = find.widgetWithText(TextFormField, 'Địa chỉ email');
        await tester.showKeyboard(emailField);
        await tester.enterText(emailField, 'user@example.com');
        await tester.ensureVisible(find.text('Gửi mã đặt lại'));
        await tester.tap(find.text('Gửi mã đặt lại'));
        await tester.pump();
        await tester.pump();

        final passwordField = find.widgetWithText(
          TextFormField,
          'Mật khẩu mới',
        );
        await tester.ensureVisible(passwordField);
        await tester.showKeyboard(passwordField);
        await tester.pump();

        expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
        expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
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

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Gửi mã đặt lại'), findsOneWidget);

    await tester.tap(find.text('Gửi mã đặt lại'));
    await tester.pump();
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Địa chỉ email'),
      '  User@Example.COM ',
    );
    await tester.tap(find.text('Gửi mã đặt lại'));
    await tester.pump();
    await tester.pump();

    expect(repository.requestedEmails, ['user@example.com']);
    expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
    expect(
      find.text(
        'Nếu mã đặt lại đã được gửi, vui lòng kiểm tra hộp thư của bạn.',
      ),
      findsOneWidget,
    );
    expect(find.text('Đã gửi mã thành công'), findsNothing);
    expect(find.text('Mã đặt lại'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu mới'), findsOneWidget);
    expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
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
      find.widgetWithText(TextFormField, 'Địa chỉ email'),
      'user@example.com',
    );
    await tester.tap(find.text('Gửi mã đặt lại'));
    await tester.pump();

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Đặt lại mật khẩu của bạn'), findsNothing);
    expect(find.text('Mã đặt lại'), findsNothing);

    requestGate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
  });

  testWidgets(
    'editing email clears its backend error and allows another request',
    (tester) async {
      const emailError = 'Invalid email format.';
      final repository = _FakePasswordRecoveryRepository(
        requestError: const ValidationFailure(
          'Không thể hoàn tất yêu cầu. Vui lòng kiểm tra lại các trường được đánh dấu.',
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

      final emailField = find.widgetWithText(TextFormField, 'Địa chỉ email');
      await tester.enterText(emailField, 'first@example.com');
      await tester.tap(find.text('Gửi mã đặt lại'));
      await tester.pump();
      await tester.pump();

      expect(find.text(emailError), findsOneWidget);
      expect(repository.requestedEmails, ['first@example.com']);

      repository.requestError = null;
      await tester.enterText(emailField, 'second@example.com');
      await tester.pump();

      expect(find.text(emailError), findsNothing);

      await tester.tap(find.text('Gửi mã đặt lại'));
      await tester.pump();
      await tester.pump();

      expect(repository.requestedEmails, [
        'first@example.com',
        'second@example.com',
      ]);
      expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
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
      find.widgetWithText(TextFormField, 'Mã đặt lại'),
      '١٢٣٤٥٦',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu mới'),
      'weak',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'different',
    );
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pump();

    expect(find.text('Vui lòng nhập đúng 6 chữ số.'), findsOneWidget);
    expect(find.text('Mật khẩu phải từ 8 đến 72 ký tự.'), findsOneWidget);
    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
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
      find.widgetWithText(TextFormField, 'Mã đặt lại'),
      '012345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu mới'),
      'NewPassword123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'NewPassword123!',
    );
    final completed = cubit.stream.firstWhere(
      (state) => state.status == PasswordRecoveryStatus.success,
    );
    await tester.tap(find.text('Đặt lại mật khẩu'));
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
        'Mật khẩu của bạn đã được đặt lại. Hãy đăng nhập bằng mật khẩu mới.',
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
      find.widgetWithText(TextButton, 'Gửi lại mã (60s)'),
    );
    expect(disabled.onPressed, isNull);

    final ready = cubit.stream.firstWhere(
      (state) => state.cooldownSeconds == 0,
    );
    ticks.add(0);
    await tester.pump();
    await ready;
    await tester.pump();
    await tester.tap(find.text('Gửi lại mã'));
    await tester.pump();
    await tester.pump();

    expect(repository.requestedEmails, [
      'user@example.com',
      'user@example.com',
    ]);
    expect(
      find.text(
        'Nếu mã mới đã được gửi, mọi mã trước đó có thể không còn hiệu lực.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('backend rejection keeps the reset form and entered values', (
    tester,
  ) async {
    const safeError =
        'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới và thử lại.';
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
      find.widgetWithText(TextFormField, 'Mã đặt lại'),
      '012345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu mới'),
      'NewPassword123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'NewPassword123!',
    );
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
    expect(find.text(safeError), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Mã đặt lại'),
          )
          .controller
          ?.text,
      '012345',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Mật khẩu mới'),
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
          'Không thể hoàn tất yêu cầu. Vui lòng kiểm tra lại các trường được đánh dấu.',
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
        find.widgetWithText(TextFormField, 'Mã đặt lại'),
        '012345',
      );
      final passwordField = find.widgetWithText(TextFormField, 'Mật khẩu mới');
      await tester.enterText(passwordField, 'FirstPassword123!');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
        'FirstPassword123!',
      );
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pump();
      await tester.pump();

      expect(find.text(passwordError), findsOneWidget);
      expect(repository.confirmed, (
        email: 'user@example.com',
        code: '012345',
        newPassword: 'FirstPassword123!',
      ));

      repository.confirmError = const ValidationFailure(
        'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.',
      );
      await tester.enterText(passwordField, 'SecondPassword123!');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
        'SecondPassword123!',
      );
      await tester.pump();

      expect(find.text(passwordError), findsNothing);

      await tester.tap(find.text('Đặt lại mật khẩu'));
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
          'Không thể hoàn tất yêu cầu. Vui lòng kiểm tra lại các trường được đánh dấu.',
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

      final codeField = find.widgetWithText(TextFormField, 'Mã đặt lại');
      await tester.enterText(codeField, '000000');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'NewPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
        'NewPassword123!',
      );
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pump();
      await tester.pump();

      expect(find.text(codeError), findsOneWidget);

      repository.confirmError = const InvalidResetCredentialFailure();
      await tester.enterText(codeField, '012345');
      await tester.pump();

      expect(find.text(codeError), findsNothing);

      await tester.tap(find.text('Đặt lại mật khẩu'));
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
      find.widgetWithText(TextFormField, 'Địa chỉ email'),
      'user@example.com',
    );
    await tester.tap(find.text('Gửi mã đặt lại'));
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

  testWidgets(
    'Change email returns to step 1 and keeps cooldown for same email',
    (tester) async {
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

      expect(find.text('Đổi email'), findsOneWidget);
      await tester.tap(find.text('Đổi email'));
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu'), findsOneWidget);
      expect(find.text('Gửi mã đặt lại (60s)'), findsOneWidget);
      expect(find.textContaining('đợi 60 giây'), findsOneWidget);
      final disabledButton = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(disabledButton.onPressed, isNull);

      await tester.tap(find.text('Nhập mã đã nhận'));
      await tester.pumpAndSettle();

      expect(repository.requestedEmails, ['user@example.com']);
      expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
    },
  );

  testWidgets(
    'Back to sign in and re-entering forgot password keeps active cooldown for same email',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var now = DateTime.utc(2026, 11, 25, 10);
      final tracker = PasswordRecoveryCooldownTracker(clock: () => now);
      final repository = _FakePasswordRecoveryRepository();
      final router = GoRouter(
        initialLocation: AppRoutes.forgotPassword,
        routes: [
          GoRoute(
            path: AppRoutes.forgotPassword,
            builder: (_, _) => BlocProvider<PasswordRecoveryCubit>(
              create: (_) => PasswordRecoveryCubit(
                repository,
                cooldownStream: (_) => const Stream<int>.empty(),
                cooldownTracker: tracker,
              ),
              child: const PasswordRecoveryPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.go(AppRoutes.forgotPassword),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _openResetForm(tester);
      expect(repository.requestedEmails, ['user@example.com']);

      // 18 seconds pass, then user taps "Quay lại đăng nhập", disposing cubit 1.
      now = now.add(const Duration(seconds: 18));
      await tester.ensureVisible(find.text('Quay lại đăng nhập'));
      await tester.tap(find.text('Quay lại đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Quên mật khẩu?'), findsOneWidget);

      // User re-opens Forgot Password (fresh route & cubit) and enters same email.
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ email'),
        'USER@example.com',
      );
      await tester.pump();

      // Send button is disabled with remaining 42s countdown; no 2nd API call.
      final sendButton = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(sendButton.onPressed, isNull);
      expect(find.text('Gửi mã đặt lại (42s)'), findsOneWidget);
      expect(find.text('Nhập mã đã nhận'), findsOneWidget);
      expect(repository.requestedEmails, ['user@example.com']);

      // Resuming jumps into Step 2 with Gửi lại mã (42s) still disabled.
      await tester.tap(find.text('Nhập mã đã nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lại mật khẩu của bạn'), findsOneWidget);
      expect(find.text('Gửi lại mã (42s)'), findsOneWidget);
      expect(repository.requestedEmails, ['user@example.com']);
    },
  );
}

Future<void> _openResetForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Địa chỉ email'),
    'user@example.com',
  );
  await tester.tap(find.text('Gửi mã đặt lại'));
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
