import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

void main() {
  testWidgets(
    'unresolved TourOperator sees an honest fail-closed status view',
    (tester) async {
      final session = AuthSessionCubit(
        null,
        _MemoryStorage({
          AppConstants.accessTokenKey: 'access',
          AppConstants.refreshTokenKey: 'refresh',
          AppConstants.sessionRoleKey: 'tourOperator',
          AppConstants.keepSignedInKey: 'true',
        }),
      );
      await session.restoreSession();
      final router = createAppRouter(session);
      addTearDown(router.dispose);
      addTearDown(session.close);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Application status unavailable'), findsOneWidget);
      expect(find.text('Rejected'), findsNothing);
      expect(find.text('Resubmit application'), findsNothing);
      expect(find.text('Operator workspace'), findsNothing);
    },
  );
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
