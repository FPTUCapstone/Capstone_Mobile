import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

void main() {
  testWidgets('router error page never renders internal exception text', (
    tester,
  ) async {
    final session = AuthSessionCubit();
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    addTearDown(session.close);

    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/internal-exception-marker');
    await tester.pumpAndSettle();

    expect(find.textContaining('internal-exception-marker'), findsNothing);
    expect(find.text('Page not found.'), findsOneWidget);
  });
}
