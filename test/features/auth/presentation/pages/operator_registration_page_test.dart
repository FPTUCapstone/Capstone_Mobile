import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_registration_page.dart';

void main() {
  testWidgets(
    'operator registration success stays unauthenticated and shows pending state',
    (tester) async {
      final session = AuthSessionCubit();
      final application = OperatorApplicationCubit(
        initialStatus: OperatorApplicationStatus.draft,
      );
      addTearDown(session.close);
      addTearDown(application.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthSessionCubit>.value(value: session),
            BlocProvider<OperatorApplicationCubit>.value(value: application),
          ],
          child: const MaterialApp(home: OperatorRegistrationPage()),
        ),
      );

      unawaited(application.submit());
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(session.state, const AuthSessionState.unauthenticated());
      expect(application.state.status, OperatorApplicationStatus.pending);
      expect(find.text('Application submitted'), findsOneWidget);
      expect(find.text('PENDING APPROVAL'), findsOneWidget);
    },
  );
}
