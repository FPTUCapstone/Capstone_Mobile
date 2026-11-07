import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/pages/operator_bookings_list_view.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_state.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_vi.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_coupons_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_dashboard_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_profile_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_revenue_view.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/notification_permission_notice.dart';

class OperatorShellPage extends StatefulWidget {
  const OperatorShellPage({this.isDemoMode = false, super.key});

  final bool isDemoMode;

  @override
  State<OperatorShellPage> createState() => _OperatorShellPageState();
}

class _OperatorShellPageState extends State<OperatorShellPage>
    with WidgetsBindingObserver {
  static const _destinations = <_OperatorDestination>[
    _OperatorDestination(
      'Dashboard',
      Icons.dashboard_outlined,
      Icons.dashboard,
    ),
    _OperatorDestination('Tours', Icons.tour_outlined, Icons.tour),
    _OperatorDestination(
      'Bookings',
      Icons.book_online_outlined,
      Icons.book_online,
    ),
    _OperatorDestination('Revenue', Icons.payments_outlined, Icons.payments),
    _OperatorDestination(
      'Coupons',
      Icons.confirmation_number_outlined,
      Icons.confirmation_number,
    ),
    _OperatorDestination('Profile', Icons.business_outlined, Icons.business),
  ];

  static const _bookingsIndex = 2;

  var _selectedIndex = 0;

  /// UC-70 inbox behind the badge. Demo mode never reaches the Backend.
  late final OperatorSafetyReviewsCubit? _safetyAlerts = widget.isDemoMode
      ? null
      : locateOptional<OperatorSafetyReviewsCubit>();

  /// The Bookings tab (UC-40) loads from the backend only once the operator first opens it.
  var _bookingsOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_safetyAlerts?.startSession());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final alerts = _safetyAlerts;
    if (alerts == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(alerts.onForeground());
    } else if (state == AppLifecycleState.paused) {
      unawaited(alerts.onBackground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Sign-out and account changes leave the shell: nothing may survive them.
    unawaited(_safetyAlerts?.reset());
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == _bookingsIndex) _bookingsOpened = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSessionCubit>();
    final state = session.state;
    // Only the approved local-cleanup notice is surfaced here; unrelated auth
    // errors are not this screen's concern.
    final localCleanupFailure =
        state.status == AuthSessionStatus.authenticated &&
        state.errorMessage ==
            AuthSessionCubit.signOutLocalCleanupFailureMessage;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Operator · ${_destinations[_selectedIndex].label}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_safetyAlerts case final alerts?) _SafetyAlertsAction(alerts),
          IconButton(
            // Busy state comes from the Cubit's own sign-out marker, so a
            // second intent cannot be started while one is in flight.
            onPressed: state.operation == AuthSessionOperation.signOut
                ? null
                : session.signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (locateOptional<PushDeviceCoordinator>() case final push?)
            NotificationPermissionNotice(
              denied: push.permissionDenied,
              window: serviceLocator<DeviceWindow>(),
            ),
          if (localCleanupFailure)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppAlert(
                message: state.errorMessage!,
                type: AppAlertType.error,
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                OperatorDashboardView(
                  isDemoMode: widget.isDemoMode,
                  onNavigateToTab: _select,
                ),
                _OperatorToursHub(),
                if (_bookingsOpened)
                  BlocProvider<OperatorBookingsCubit>(
                    create: (_) => serviceLocator<OperatorBookingsCubit>(
                      param1: widget.isDemoMode,
                    )..loadInitial(),
                    child: OperatorBookingsListView(
                      isDemoMode: widget.isDemoMode,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                OperatorRevenueView(isDemoMode: widget.isDemoMode),
                OperatorCouponsView(isDemoMode: widget.isDemoMode),
                const OperatorProfileView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SafetyAlertsAction extends StatelessWidget {
  const _SafetyAlertsAction(this.alerts);

  final OperatorSafetyReviewsCubit alerts;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OperatorSafetyReviewsCubit, OperatorSafetyReviewsState>(
        bloc: alerts,
        buildWhen: (previous, current) =>
            previous.badgeCount != current.badgeCount,
        builder: (context, state) {
          const icon = Icon(Icons.health_and_safety_outlined);
          final count = state.badgeCount;
          return IconButton(
            key: const Key('operator-safety-alerts'),
            tooltip: count == 0
                ? OperatorWeatherSafetyStringsVi.safetyAlerts
                : OperatorWeatherSafetyStringsVi.badgeSemantics(count),
            onPressed: () => context.push(AppRoutes.operatorSafetyReviews),
            icon: count == 0 ? icon : Badge(label: Text('$count'), child: icon),
          );
        },
      );
}

class _OperatorToursHub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.tour_outlined,
                size: 38,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Manage tours',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const Text(
                'Create a commercial tour package, keep editing your drafts and submit them for review.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.operatorTours),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('My tour packages'),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.createTourPackage),
              icon: const Icon(Icons.add),
              label: const Text('Create tour package'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorDestination {
  const _OperatorDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
