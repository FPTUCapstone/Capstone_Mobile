import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_realtime.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_repository.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/my_trips_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_home_dashboard_view.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_profile_view.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_notices_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/widgets/traveler_emergency_banner.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';
import 'package:trip_mate_mobile/shared/widgets/notification_permission_notice.dart';

enum TravelerSectionId { home, trips, explore, bookings, profile }

class TravelerShellPage extends StatefulWidget {
  const TravelerShellPage({
    this.initialSection = TravelerSectionId.home,
    super.key,
  });

  final TravelerSectionId initialSection;

  @override
  State<TravelerShellPage> createState() => _TravelerShellPageState();
}

class _TravelerShellPageState extends State<TravelerShellPage>
    with WidgetsBindingObserver {
  static const _destinations = <_TravelerDestination>[
    _TravelerDestination(
      TravelerSectionId.home,
      'Trang chủ',
      Icons.home_outlined,
      Icons.home,
    ),
    _TravelerDestination(
      TravelerSectionId.trips,
      'Chuyến đi',
      Icons.map_outlined,
      Icons.map,
    ),
    _TravelerDestination(
      TravelerSectionId.explore,
      'Khám phá',
      Icons.explore_outlined,
      Icons.explore,
    ),
    _TravelerDestination(
      TravelerSectionId.bookings,
      'Đặt chỗ',
      Icons.confirmation_number_outlined,
      Icons.confirmation_number,
    ),
    _TravelerDestination(
      TravelerSectionId.profile,
      'Hồ sơ',
      Icons.person_outline,
      Icons.person,
    ),
  ];

  var _selectedIndex = 0;
  late final PoiListCubit _exploreCubit;
  late final MyTripsCubit _myTripsCubit;
  var _exploreLoaded = false;
  var _toursOpened = false;
  final TravelerEmergencyNoticesCubit? _notices =
      locateOptional<TravelerEmergencyNoticesCubit>();
  final InAppNotificationRepository? _inboxRepository =
      locateOptional<InAppNotificationRepository>();
  final InAppNotificationRealtime? _inboxRealtime =
      locateOptional<InAppNotificationRealtime>();
  StreamSubscription<void>? _inboxRealtimeSub;
  var _unreadInboxCount = 0;
  var _unreadInboxHasMore = false;
  var _inboxRequestEpoch = 0;
  late final AuthSessionCubit _session = context.read<AuthSessionCubit>();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_notices?.refresh());
      unawaited(_refreshUnreadInbox());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_inboxRealtime?.stop());
    }
  }

  Future<void> _refreshUnreadInbox() async {
    final repository = _inboxRepository;
    if (repository == null || !_session.state.isAuthenticated) return;
    final epoch = ++_inboxRequestEpoch;
    try {
      final page = await repository.getInbox(unreadOnly: true, limit: 50);
      if (!mounted || epoch != _inboxRequestEpoch) return;
      setState(() {
        _unreadInboxCount = page.items.length;
        _unreadInboxHasMore = page.nextBeforeId != null;
      });
      // Start SignalR only after an authorized HTTP request succeeds so any
      // expired access token has already been refreshed by Dio's interceptor.
      if (_session.state.isAuthenticated) {
        unawaited(_inboxRealtime?.start());
      }
    } catch (_) {
      // Keep the Home shell quiet if the unread badge cannot be loaded.
    }
  }

  Future<void> _openInbox() async {
    await context.pushNamed(AppRouteNames.inAppInbox);
    if (!mounted) return;
    await _refreshUnreadInbox();
  }

  void _openNotice(int? bookingId) => context.push(
    bookingId == null
        ? AppRoutes.tripHistory
        : AppRoutes.travelerEmergency(bookingId),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Read now: dispose() can no longer look it up.
    _session;
    unawaited(_notices?.refresh());
    if (_inboxRealtime case final realtime?) {
      _inboxRealtimeSub = realtime.changes.listen(
        (_) => unawaited(_refreshUnreadInbox()),
      );
    }
    unawaited(_refreshUnreadInbox());
    _exploreCubit = serviceLocator<PoiListCubit>();
    _myTripsCubit = serviceLocator<MyTripsCubit>();
    _selectedIndex = widget.initialSection.index;
    _toursOpened = widget.initialSection == TravelerSectionId.bookings;
    if (widget.initialSection == TravelerSectionId.explore) {
      _exploreLoaded = true;
      unawaited(_exploreCubit.loadInitial());
    } else if (widget.initialSection == TravelerSectionId.trips) {
      unawaited(_myTripsCubit.load());
    }
  }

  void _selectSection(int index) {
    if (index == 0) {
      unawaited(_refreshUnreadInbox());
    }
    if (index == 1) {
      // Reloaded on every visit: trips change in pushed routes.
      unawaited(_myTripsCubit.load());
    }
    if (index == 2 && !_exploreLoaded) {
      _exploreLoaded = true;
      unawaited(_exploreCubit.loadInitial());
    }
    setState(() {
      _selectedIndex = index;
      if (index == 3) _toursOpened = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_inboxRealtimeSub?.cancel());
    unawaited(_inboxRealtime?.dispose());
    // Sign-out and account changes leave the shell: nothing may survive them.
    // A route replacing the shell mid-session must keep the list, which Trip
    // History is reading at that very moment.
    if (!_session.state.isAuthenticated) _notices?.reset();
    _exploreCubit.close();
    _myTripsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSessionCubit>();
    final state = session.state;
    final localCleanupFailure =
        state.status == AuthSessionStatus.authenticated &&
        state.errorMessage ==
            AuthSessionCubit.signOutLocalCleanupFailureMessage;

    return Scaffold(
      appBar: _selectedIndex == 2 || _selectedIndex == 3
          ? null
          : AppBar(
              title: _buildAppBarTitle(_selectedIndex),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              actions: [
                IconButton(
                  key: const Key('traveler_messages_nav_button'),
                  tooltip: 'Tin nhắn',
                  icon: const Icon(Icons.chat_bubble_outline, size: 21),
                  onPressed: () => context.push(AppRoutes.travelerMessages),
                ),
                IconButton(
                  tooltip: 'Hỗ trợ',
                  icon: const Icon(Icons.support_agent_outlined, size: 22),
                  onPressed: () => context.push(AppRoutes.supportChat),
                ),
                if (_selectedIndex == 0)
                  IconButton(
                    key: const Key('traveler_inbox_nav_button'),
                    icon: Badge(
                      isLabelVisible: _unreadInboxCount > 0,
                      label: Text(
                        _unreadInboxHasMore ? '50+' : '$_unreadInboxCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: const Color(0xFFD92D20),
                      child: const Icon(
                        Icons.notifications_none_outlined,
                        size: 22,
                      ),
                    ),
                    tooltip: 'Thông báo',
                    onPressed: () => unawaited(_openInbox()),
                  ),
                const SizedBox(width: 4),
              ],
            ),
      body: Column(
        children: [
          if (_notices case final notices?)
            BlocBuilder<
              TravelerEmergencyNoticesCubit,
              TravelerEmergencyNoticesState
            >(
              bloc: notices,
              builder: (_, state) => TravelerEmergencyBanner(
                unread: state.unread,
                onOpen: _openNotice,
              ),
            ),
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
                BlocProvider.value(
                  value: _myTripsCubit,
                  child: TravelerHomeDashboardView(
                    isActive: _selectedIndex == 0,
                    onOpenTours: () => _selectSection(3),
                    onOpenExplore: () => _selectSection(2),
                  ),
                ),
                BlocProvider.value(
                  value: _myTripsCubit,
                  child: const MyTripsPage(),
                ),
                BlocProvider.value(
                  value: _exploreCubit,
                  child: ExplorePoiPage(
                    isTraveler: true,
                    onOpenTours: () => _selectSection(3),
                  ),
                ),
                if (_toursOpened)
                  BlocProvider<TourSearchCubit>(
                    create: (_) =>
                        serviceLocator<TourSearchCubit>()..loadInitial(),
                    child: const TourSearchPage(
                      isTraveler: true,
                      showBackButton: false,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                const TravelerProfileView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppSlidingBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectSection,
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

  Widget _buildAppBarTitle(int index) {
    if (index == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo/tripmate_logo_full_512.png',
            height: 24,
            fit: BoxFit.contain,
          ),
        ],
      );
    }
    return Text(_destinations[index].label);
  }
}

class _TravelerDestination {
  const _TravelerDestination(
    this.section,
    this.label,
    this.icon,
    this.selectedIcon,
  );

  final TravelerSectionId section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
