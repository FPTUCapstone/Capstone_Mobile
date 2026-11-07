import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/emergency_push_handler.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/push/emergency_push_hint.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_notices_cubit.dart';

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
  StreamSubscription<EmergencyPushHint>? _emergencyPushSubscription;
  AppLifecycleListener? _lifecycle;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final _emergencyPush = EmergencyPushHandler(
    open: (location) => _router.push(location),
    refresh: (hint) async => switch (hint) {
      OperatorReviewHint() =>
        await locateOptional<OperatorSafetyReviewsCubit>()?.refresh(),
      TravelerBookingHint() =>
        await locateOptional<TravelerEmergencyNoticesCubit>()?.refresh(),
    },
    surface: (location) => _messengerKey.currentState?.showSnackBar(
      emergencyUpdateSnackBar(onOpen: () => _router.push(location)),
    ),
    dismissSurface: () => _messengerKey.currentState?.clearSnackBars(),
  );
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _sessionCoordinator.register(_sessionCubit.handleSessionExpired);
    if (serviceLocator.isRegistered<PushDeviceCoordinator>()) {
      final push = serviceLocator<PushDeviceCoordinator>();
      _pushSubscription = push.hints.listen(_handlePushHint);
      _emergencyPushSubscription = push.emergencyHints.listen(
        (hint) => unawaited(_emergencyPush.handle(hint)),
      );
      push.listen();
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(push.onResumed()),
        // An update announced earlier is stale by the time the app returns. A
        // push can also land during the switch, after onHide has already run.
        onHide: () => _messengerKey.currentState?.clearSnackBars(),
        onShow: () => _messengerKey.currentState?.clearSnackBars(),
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
    unawaited(_emergencyPushSubscription?.cancel());
    _lifecycle?.dispose();
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
          scaffoldMessengerKey: _messengerKey,
          builder: (context, child) {
            Widget content = Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (_showSplash)
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _showSplash
                          ? SplashPage(
                              autoNavigate: true,
                              onFinished: () {
                                if (mounted) {
                                  setState(() => _showSplash = false);
                                }
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            );

            if (kIsWeb) {
              return ColoredBox(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: content,
                  ),
                ),
              );
            }

            return content;
          },
        ),
      ),
    );
  }
}
