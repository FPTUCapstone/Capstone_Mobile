import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

class TravelerShellPage extends StatefulWidget {
  const TravelerShellPage({super.key});

  @override
  State<TravelerShellPage> createState() => _TravelerShellPageState();
}

class _TravelerShellPageState extends State<TravelerShellPage> {
  static const _destinations = <_TravelerDestination>[
    _TravelerDestination('Home', Icons.home_outlined),
    _TravelerDestination('Trips', Icons.map_outlined),
    _TravelerDestination('Explore', Icons.explore_outlined),
    _TravelerDestination('Bookings', Icons.confirmation_number_outlined),
    _TravelerDestination('Profile', Icons.person_outline),
  ];

  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Traveler · ${_destinations[_selectedIndex].label}'),
        actions: [
          IconButton(
            onPressed: context.read<AuthSessionCubit>().clearPreviewSession,
            tooltip: 'Exit preview',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _destinations
            .map((destination) => _TravelerSection(destination: destination))
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
            const Text('Feature placeholder', textAlign: TextAlign.center),
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
