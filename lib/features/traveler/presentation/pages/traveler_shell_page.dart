import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/my_trips_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_bookings_view.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_home_dashboard_view.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_profile_view.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';

enum TravelerSectionId { home, trips, explore, bookings, profile }

class TravelerShellPage extends StatefulWidget {
  const TravelerShellPage({super.key});

  @override
  State<TravelerShellPage> createState() => _TravelerShellPageState();
}

class _TravelerShellPageState extends State<TravelerShellPage> {
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

  @override
  void initState() {
    super.initState();
    _exploreCubit = serviceLocator<PoiListCubit>();
    _myTripsCubit = serviceLocator<MyTripsCubit>();
  }

  @override
  void dispose() {
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
      appBar: _selectedIndex == 2
          ? null
          : AppBar(
              title: _buildAppBarTitle(_selectedIndex),
              actions: [
                if (_selectedIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    tooltip: 'Thông báo',
                    onPressed: () {},
                  ),
                IconButton(
                  onPressed: state.operation == AuthSessionOperation.signOut
                      ? null
                      : session.signOut,
                  tooltip: 'Đăng xuất',
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
      body: Column(
        children: [
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
                  child: const TravelerHomeDashboardView(),
                ),
                BlocProvider.value(
                  value: _myTripsCubit,
                  child: const MyTripsPage(),
                ),
                BlocProvider.value(
                  value: _exploreCubit,
                  child: const ExplorePoiPage(isTraveler: true),
                ),
                const TravelerBookingsView(),
                const TravelerProfileView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppSlidingBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            // Reloaded on every visit: trips change in pushed routes.
            _myTripsCubit.load();
          }
          if (index == 2 && !_exploreLoaded) {
            _exploreLoaded = true;
            _exploreCubit.loadInitial();
          }
          setState(() => _selectedIndex = index);
        },
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
            height: 28,
            fit: BoxFit.contain,
          ),
        ],
      );
    }
    return Text(
      _destinations[index].label,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
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
