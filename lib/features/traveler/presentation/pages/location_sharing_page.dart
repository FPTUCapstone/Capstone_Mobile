import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/location_sharing_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

final class LocationSharingPage extends StatelessWidget {
  const LocationSharingPage({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Group location sharing')),
    body: BlocBuilder<LocationSharingCubit, LocationSharingState>(
      builder: (context, state) => switch (state.status) {
        LocationSharingStatus.initial || LocationSharingStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        LocationSharingStatus.forbidden => const ErrorView(
          message: 'Only active members can use this group’s location sharing.',
        ),
        LocationSharingStatus.notFound => const ErrorView(
          message: 'This travel group could not be found.',
        ),
        LocationSharingStatus.error => ErrorView(
          message: 'Could not load location sharing settings.',
          onRetry: () => context.read<LocationSharingCubit>().load(groupId),
        ),
        LocationSharingStatus.ready => _Content(state: state),
      },
    ),
  );
}

final class _Content extends StatelessWidget {
  const _Content({required this.state});

  final LocationSharingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LocationSharingCubit>();
    final activelySharing = state.enabled && state.permissionGranted;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Your exact location is visible only to active members of this group while you opt in and device location permission is granted.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile.adaptive(
            key: const Key('share-location-switch'),
            title: const Text('Share my location with this group'),
            subtitle: Text(
              activelySharing
                  ? 'Enabled while the app is open'
                  : state.enabled
                  ? 'Paused: device location permission is unavailable'
                  : 'Off',
            ),
            value: state.enabled,
            onChanged: state.saving
                ? null
                : (value) => unawaited(cubit.setEnabled(value)),
          ),
        ),
        if (state.saving) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          state.permissionGranted
              ? 'Device location permission: granted'
              : 'Device location permission: unavailable. Location is not shared.',
        ),
        if (!state.permissionGranted) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(cubit.openSettings()),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open Device Settings'),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 12),
          Text(state.message!, key: const Key('location-sharing-message')),
        ],
        const SizedBox(height: 24),
        Text(
          'Recently shared group locations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (state.locations.isEmpty)
          const Text(
            'No current group locations are available. Old positions expire automatically.',
          ),
        for (final location in state.locations)
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text('Group member #${location.userId}'),
              subtitle: Text(
                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)} · '
                '${TimeOfDay.fromDateTime(location.recordedAtUtc.toLocal()).format(context)}',
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
