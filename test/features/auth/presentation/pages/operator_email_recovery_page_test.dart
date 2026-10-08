import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_email_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_email_recovery_page.dart';

void main() {
  late _Identity identity;
  late _Repository repository;
  late OperatorEmailRecoveryCubit cubit;

  setUp(() {
    identity = _Identity();
    repository = _Repository();
    cubit = OperatorEmailRecoveryCubit(
      RegisterTourOperator(
        repository: repository,
        identityService: identity,
        verificationContinueUrl: () =>
            Uri.parse('https://tripmate.example/verify-email?flow=operator'),
      ),
    );
  });
  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.operatorEmailRecovery,
      routes: [
        GoRoute(
          path: AppRoutes.operatorEmailRecovery,
          builder: (_, _) => BlocProvider<OperatorEmailRecoveryCubit>.value(
            value: cubit,
            child: const OperatorEmailRecoveryPage(email: 'owner@example.com'),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('Sign in destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  testWidgets('resends to the existing account without registering again', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('owner@example.com'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Secure123!',
    );
    await tester.scrollUntilVisible(
      find.text('Send verification email'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send verification email'));
    await tester.pump();

    expect(identity.recoveries, 1);
    expect(identity.sentEmails, 1);
    expect(repository.posts, 0);
    expect(find.textContaining('Verification email sent'), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
  });

  testWidgets('checks verified identity with backend before suggesting login', (
    tester,
  ) async {
    identity.verified = true;
    await pumpPage(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Secure123!',
    );
    await tester.scrollUntilVisible(
      find.text("I've verified my email"),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();

    expect(repository.confirmations, 1);
    expect(repository.posts, 0);
    expect(
      find.text('Email verified. Sign in to check your application status.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Sign In'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in destination'), findsOneWidget);
  });

  testWidgets('does not claim success before email is verified', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Secure123!',
    );
    await tester.scrollUntilVisible(
      find.text("I've verified my email"),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();

    expect(repository.confirmations, 0);
    expect(find.textContaining('not verified yet'), findsOneWidget);
  });
}

final class _Repository implements TourOperatorRegistrationRepository {
  int posts = 0;
  int confirmations = 0;

  @override
  Future<TourOperatorRegistrationResult> register(
    TourOperatorRegistration registration,
    String firebaseIdToken,
  ) async {
    posts++;
    return const TourOperatorRegistrationResult(
      userId: 1,
      applicationStatus: 'PendingApproval',
      messageCode: 'MSG08',
    );
  }

  @override
  Future<void> confirmVerifiedEmail(String firebaseIdToken) async {
    confirmations++;
  }
}

final class _Identity implements OperatorRegistrationIdentityService {
  int recoveries = 0;
  int sentEmails = 0;
  bool verified = false;

  @override
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteNewlyCreated(String userId) => throw UnimplementedError();

  @override
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  }) async {
    recoveries++;
    return const OperatorCreatedIdentity(userId: 'uid-1', idToken: 'token');
  }

  @override
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl) async {
    sentEmails++;
  }

  @override
  Future<String?> verifiedIdTokenFor(String email) async =>
      verified ? 'verified-token' : null;
}
