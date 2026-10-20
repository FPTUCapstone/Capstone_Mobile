import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_bookings_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_coupons_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_dashboard_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_profile_view.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_revenue_view.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

class OperatorShellPage extends StatefulWidget {
  const OperatorShellPage({super.key});

  @override
  State<OperatorShellPage> createState() => _OperatorShellPageState();
}

class _OperatorShellPageState extends State<OperatorShellPage> {
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

  var _selectedIndex = 0;

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
                  onNavigateToTab: (index) =>
                      setState(() => _selectedIndex = index),
                ),
                _OperatorToursHub(),
                const OperatorBookingsView(),
                const OperatorRevenueView(),
                const OperatorCouponsView(),
                const OperatorProfileView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
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
