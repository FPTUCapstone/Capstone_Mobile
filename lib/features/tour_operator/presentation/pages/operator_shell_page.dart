import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

class OperatorShellPage extends StatefulWidget {
  const OperatorShellPage({super.key});

  @override
  State<OperatorShellPage> createState() => _OperatorShellPageState();
}

class _OperatorShellPageState extends State<OperatorShellPage> {
  static const _destinations = <_OperatorDestination>[
    _OperatorDestination('Dashboard', Icons.dashboard_outlined),
    _OperatorDestination('Tours', Icons.tour_outlined),
    _OperatorDestination('Bookings', Icons.book_online_outlined),
    _OperatorDestination('Revenue', Icons.payments_outlined),
    _OperatorDestination('Profile', Icons.business_outlined),
  ];

  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Operator · ${_destinations[_selectedIndex].label}'),
        actions: [
          IconButton(
            onPressed: context.read<AuthSessionCubit>().clearSession,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _destinations
            .map((destination) => _OperatorSection(destination: destination))
            .toList(growable: false),
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
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _OperatorSection extends StatelessWidget {
  const _OperatorSection({required this.destination});

  final _OperatorDestination destination;

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
              'Operator ${destination.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text('Feature placeholder', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _OperatorDestination {
  const _OperatorDestination(this.label, this.icon);

  final IconData icon;
  final String label;
}
