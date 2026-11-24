import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_profile_view.dart';

void main() {
  testWidgets('contract entry renders without obscuring Material ink', (
    tester,
  ) async {
    final session = AuthSessionCubit();
    addTearDown(session.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: session,
        child: const MaterialApp(home: Scaffold(body: OperatorProfileView())),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Hợp đồng đối tác'), findsOneWidget);
  });
}
