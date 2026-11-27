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
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';
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
      'Tổng quan',
      Icons.dashboard_outlined,
      Icons.dashboard_rounded,
    ),
    _OperatorDestination('Tour', Icons.tour_outlined, Icons.tour_rounded),
    _OperatorDestination(
      'Đơn đặt',
      Icons.book_online_outlined,
      Icons.book_online_rounded,
    ),
    _OperatorDestination(
      'Tài chính',
      Icons.payments_outlined,
      Icons.payments_rounded,
    ),
    _OperatorDestination(
      'Hồ sơ',
      Icons.business_outlined,
      Icons.business_rounded,
    ),
  ];

  static const _bookingsIndex = 2;
  static const _financeIndex = 3;
  static const _profileIndex = 4;
  static const _couponsVirtualIndex = 4;

  var _selectedIndex = 0;

  /// UC-70 inbox behind the badge. Demo mode never reaches the Backend.
  late final OperatorSafetyReviewsCubit? _safetyAlerts = widget.isDemoMode
      ? null
      : locateOptional<OperatorSafetyReviewsCubit>();

  /// The Bookings tab (UC-40) loads from the backend only once the operator first opens it.
  var _bookingsOpened = false;
  var _financeOpened = false;
  var _profileOpened = false;

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
      if (index == _financeIndex) _financeOpened = true;
      if (index == _profileIndex) _profileOpened = true;
    });
  }

  void _handleDashboardNavigation(int index) {
    if (index == _couponsVirtualIndex) {
      _openCoupons();
      return;
    }
    if (index >= 0 && index < _destinations.length) {
      _select(index);
    }
  }

  void _openCoupons() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: const Text('Mã khuyến mãi'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: AppColors.line),
            ),
          ),
          body: OperatorCouponsView(isDemoMode: widget.isDemoMode),
        ),
      ),
    );
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Đối tác · ${_destinations[_selectedIndex].label}',
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('operator_messages_nav_button'),
            tooltip: 'Tin nhắn',
            icon: const Icon(Icons.chat_bubble_outline, size: 21),
            onPressed: () => context.push(AppRoutes.operatorMessages),
          ),
          if (!widget.isDemoMode)
            IconButton(
              onPressed: () => context.pushNamed(AppRouteNames.operatorInbox),
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined, size: 22),
            ),
          if (_safetyAlerts case final alerts?) _SafetyAlertsAction(alerts),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
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
                  isActive: _selectedIndex == 0,
                  onNavigateToTab: _handleDashboardNavigation,
                ),
                _OperatorToursHub(onOpenCoupons: _openCoupons),
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
                if (_financeOpened)
                  OperatorRevenueView(
                    isDemoMode: widget.isDemoMode,
                    isActive: _selectedIndex == _financeIndex,
                  )
                else
                  const SizedBox.shrink(),
                if (_profileOpened)
                  OperatorProfileView(isDemoMode: widget.isDemoMode)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppSlidingBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: _destinations
            .map(
              (destination) => AppNavDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon,
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
  const _OperatorToursHub({required this.onOpenCoupons});

  final VoidCallback onOpenCoupons;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.tour_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Quản lý gói tour',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Tạo gói tour thương mại, chỉnh sửa bản nháp, gửi duyệt và quản lý mã ưu đãi cho khách.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.createTourPackage),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo gói tour mới'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.operatorTours),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('Danh sách gói tour'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('operator-open-coupons-button'),
                  onPressed: onOpenCoupons,
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 18,
                  ),
                  label: const Text('Mã khuyến mãi & Coupon'),
                ),
              ),
            ],
          ),
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
