import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

class TravelerShellPage extends StatefulWidget {
  const TravelerShellPage({super.key});

  @override
  State<TravelerShellPage> createState() => _TravelerShellPageState();
}

class _TravelerShellPageState extends State<TravelerShellPage> {
  static const _destinations = <_TravelerDestination>[
    _TravelerDestination('Trang chủ', Icons.home_outlined),
    _TravelerDestination('Chuyến đi', Icons.map_outlined),
    _TravelerDestination('Khám phá', Icons.explore_outlined),
    _TravelerDestination('Đặt chỗ', Icons.confirmation_number_outlined),
    _TravelerDestination('Hồ sơ', Icons.person_outline),
  ];

  var _selectedIndex = 0;
  late final PoiListCubit _exploreCubit;
  var _exploreLoaded = false;

  @override
  void initState() {
    super.initState();
    _exploreCubit = serviceLocator<PoiListCubit>();
  }

  @override
  void dispose() {
    _exploreCubit.close();
    super.dispose();
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
      appBar: _selectedIndex == 2
          ? null
          : AppBar(
              title: Text('Traveler · ${_destinations[_selectedIndex].label}'),
              actions: [
                IconButton(
                  // Busy state comes from the Cubit's own sign-out marker, so
                  // a second intent cannot start while one is in flight.
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
                _TravelerSection(destination: _destinations[0]),
                _TravelerSection(destination: _destinations[1]),
                BlocProvider.value(
                  value: _exploreCubit,
                  child: const ExplorePoiPage(isTraveler: true),
                ),
                _TravelerSection(destination: _destinations[3]),
                _TravelerSection(destination: _destinations[4]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 2 && !_exploreLoaded) {
            _exploreLoaded = true;
            _exploreCubit.loadInitial();
          }
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _TravelerSection extends StatelessWidget {
  const _TravelerSection({required this.destination});

  final _TravelerDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destination.icon,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Traveler ${destination.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              destination.label == 'Trang chủ'
                  ? 'Your next adventure starts here.'
                  : 'Feature placeholder',
              textAlign: TextAlign.center,
            ),
            if (destination.label == 'Trang chủ') ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.tourSearch),
                icon: const Icon(Icons.tour_outlined),
                label: const Text('Tìm kiếm Tour'),
              ),
            ],
            if (destination.label == 'Trang chủ' ||
                destination.label == 'Hồ sơ') ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.travelerSettings),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Account settings'),
              ),
            ],
            if (destination.label == 'Trang chủ' ||
                destination.label == 'Chuyến đi') ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.joinTravelGroup),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Join travel group'),
              ),
            ],
            if (destination.label == 'Chuyến đi') ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.createItinerary),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Create an itinerary'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TravelerDestination {
  const _TravelerDestination(this.label, this.icon);

  final IconData icon;
  final String label;
}
