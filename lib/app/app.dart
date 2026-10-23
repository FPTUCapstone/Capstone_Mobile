import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';

class TripMateApp extends StatefulWidget {
  const TripMateApp({super.key});

  @override
  State<TripMateApp> createState() => _TripMateAppState();
}

class _TripMateAppState extends State<TripMateApp> {
  late final AuthSessionCubit _sessionCubit = serviceLocator();
  late final SessionCoordinator _sessionCoordinator = serviceLocator();
  late final GoRouter _router = createAppRouter(_sessionCubit);
  StreamSubscription<TripPushHint>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    _sessionCoordinator.register(_sessionCubit.handleSessionExpired);
    if (serviceLocator.isRegistered<PushDeviceCoordinator>()) {
      _pushSubscription = serviceLocator<PushDeviceCoordinator>().hints.listen(
        _handlePushHint,
      );
    }
    unawaited(_sessionCubit.restoreSession());
  }

  Future<void> _handlePushHint(TripPushHint hint) async {
    if (!hint.opened || hint.sessionId == null) return;
    try {
      final session = await serviceLocator<NavigationSessionRepository>()
          .getById(hint.sessionId!);
      _router.go(
        '${AppRoutes.activeTripLive(session.itineraryId)}'
        '?incidentId=${hint.incidentId}',
      );
    } catch (_) {
      // The push is a hint. A stale or inaccessible session is ignored.
    }
  }

  @override
  void dispose() {
    unawaited(_pushSubscription?.cancel());
    _router.dispose();
    _sessionCoordinator.unregister(_sessionCubit.handleSessionExpired);
    unawaited(_sessionCubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider<AuthSessionCubit>.value(value: _sessionCubit)],
      child: BlocListener<AuthSessionCubit, Object?>(
        listener: (_, _) => _router.refresh(),
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: _router,
        ),
      ),
    );
  }
}
