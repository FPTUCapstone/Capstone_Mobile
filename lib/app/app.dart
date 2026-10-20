import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';

class TripMateApp extends StatefulWidget {
  const TripMateApp({super.key});

  @override
  State<TripMateApp> createState() => _TripMateAppState();
}

class _TripMateAppState extends State<TripMateApp> {
  late final AuthSessionCubit _sessionCubit = serviceLocator();
  late final SessionCoordinator _sessionCoordinator = serviceLocator();
  late final GoRouter _router = createAppRouter(_sessionCubit);
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _sessionCoordinator.register(_sessionCubit.handleSessionExpired);
    unawaited(_sessionCubit.restoreSession());
  }

  @override
  void dispose() {
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
