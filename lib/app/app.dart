import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/group_location_publisher.dart';

class TripMateApp extends StatefulWidget {
  const TripMateApp({super.key});

  @override
  State<TripMateApp> createState() => _TripMateAppState();
}

class _TripMateAppState extends State<TripMateApp> with WidgetsBindingObserver {
  late final AuthSessionCubit _sessionCubit = serviceLocator();
  late final SessionCoordinator _sessionCoordinator = serviceLocator();
  late final GoRouter _router = createAppRouter(_sessionCubit);
  late final GroupLocationPublisher? _locationPublisher =
      serviceLocator.isRegistered<GroupLocationPublisher>()
      ? serviceLocator<GroupLocationPublisher>()
      : null;
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionCoordinator.register(_sessionCubit.handleSessionExpired);
    unawaited(_sessionCubit.restoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final publisher = _locationPublisher;
    if (publisher != null) unawaited(publisher.stopAll());
    _router.dispose();
    _sessionCoordinator.unregister(_sessionCubit.handleSessionExpired);
    unawaited(_sessionCubit.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final publisher = _locationPublisher;
    if (publisher == null) return;
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      if (_isAuthenticatedTraveler(_sessionCubit.state)) {
        unawaited(publisher.resume());
      } else {
        unawaited(publisher.stopAll());
      }
    } else if (state == AppLifecycleState.detached) {
      _appInForeground = false;
      unawaited(publisher.stopAll());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _appInForeground = false;
      unawaited(publisher.suspend());
    }
  }

  bool _isAuthenticatedTraveler(AuthSessionState session) =>
      session.isAuthenticated && session.role == UserRole.traveler;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider<AuthSessionCubit>.value(value: _sessionCubit)],
      child: BlocListener<AuthSessionCubit, AuthSessionState>(
        listener: (_, session) {
          _router.refresh();
          final publisher = _locationPublisher;
          if (publisher == null) return;
          if (_isAuthenticatedTraveler(session) && _appInForeground) {
            unawaited(publisher.resume().catchError((Object _) {}));
          } else if (_isAuthenticatedTraveler(session)) {
            unawaited(publisher.suspend());
          } else {
            unawaited(publisher.stopAll());
          }
        },
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
