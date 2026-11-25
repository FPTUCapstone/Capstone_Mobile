import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/auth_mapper.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_onboarding_state.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

void main() {
  test(
    'maps new onboarding state, preserves legacy absence, and rejects unknowns',
    () {
      Map<String, dynamic> payload() => {
        'userId': 1,
        'status': 'Active',
        'role': 'TourOperator',
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'applicationStatus': 'Approved',
      };
      expect(
        SessionResponseDto.fromJson(payload()).toDomain().onboardingState,
        isNull,
      );
      expect(
        SessionResponseDto.fromJson({
          ...payload(),
          'onboardingState': 'AwaitingSignature',
          'contractStatus': 'PendingSignature',
          'currentContractId': '9007199254740993',
        }).toDomain().onboardingState,
        OperatorOnboardingState.awaitingSignature,
      );
      expect(
        SessionResponseDto.fromJson({
          ...payload(),
          'onboardingState': 'Unexpected',
        }).toDomain().onboardingState,
        OperatorOnboardingState.unresolved,
      );
    },
  );

  Future<String> destination(
    WidgetTester tester,
    AuthSessionState session,
    String initial,
  ) async {
    final router = GoRouter(
      initialLocation: initial,
      redirect: (_, state) => RouteGuards.redirect(session, state),
      routes: [
        for (final path in [
          AppRoutes.login,
          AppRoutes.operator,
          AppRoutes.operatorApplication,
          AppRoutes.operatorContract,
          AppRoutes.createCoupon,
          AppRoutes.traveler,
        ])
          GoRoute(path: path, builder: (_, _) => Text(path)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router.routerDelegate.currentConfiguration.last.matchedLocation;
  }

  testWidgets('awaiting signature cannot deep link into business screens', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.approved,
      onboardingState: OperatorOnboardingState.awaitingSignature,
    );
    expect(
      await destination(tester, session, AppRoutes.createCoupon),
      AppRoutes.operatorContract,
    );
  });
  testWidgets('legacy approved operator keeps access without contract fields', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.approved,
    );
    expect(
      await destination(tester, session, AppRoutes.login),
      AppRoutes.operator,
    );
  });
  testWidgets('unknown onboarding cannot enter the workspace', (tester) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.approved,
      onboardingState: OperatorOnboardingState.unresolved,
    );
    expect(
      await destination(tester, session, AppRoutes.operator),
      AppRoutes.operatorApplication,
    );
  });
}
