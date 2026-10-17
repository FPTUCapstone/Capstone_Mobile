import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';

/// The leg between two stops: "9,4 km · khoảng 22 phút · Xe máy [Đổi]".
/// [onChangeMode] is null when the leg cannot be changed (read-only access,
/// navigation in progress, or the leg leaves the starting point).
final class ItineraryLegRow extends StatelessWidget {
  const ItineraryLegRow({
    required this.minutes,
    required this.meters,
    required this.mode,
    this.destinationName,
    this.onChangeMode,
    this.showWalkHint = true,
    super.key,
  });

  final int minutes;
  final int? meters;
  final TransportMode? mode;

  /// The stop this leg reaches, for screen readers.
  final String? destinationName;
  final ValueChanged<TransportMode>? onChangeMode;
  final bool showWalkHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final meters = this.meters;
    final mode = this.mode;
    final summary = [
      if (meters != null) formatLegDistance(meters),
      'khoảng ${vietnameseDuration(minutes)}',
      if (mode != null) transportLabel(mode),
    ].join(' · ');
    final showWalkHint =
        this.showWalkHint &&
        meters != null &&
        meters < 1000 &&
        mode != TransportMode.walking;
    final onChangeMode = this.onChangeMode;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            _icon(mode),
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: theme.textTheme.bodySmall),
                if (showWalkHint)
                  Text(
                    'Gần, có thể đi bộ ~${walkingMinutes(meters)} phút',
                    style: muted,
                  ),
              ],
            ),
          ),
          if (onChangeMode != null)
            TextButton(
              onPressed: () async {
                final selected = await showTransportModeSheet(
                  context,
                  current: mode,
                );
                if (selected != null && selected != mode) {
                  onChangeMode(selected);
                }
              },
              child: Semantics(
                label:
                    'Đổi phương tiện đến ${destinationName ?? 'điểm tiếp theo'}',
                excludeSemantics: true,
                child: const Text('Đổi'),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(TransportMode? mode) => switch (mode) {
    TransportMode.walking => Icons.directions_walk,
    TransportMode.car => Icons.directions_car_outlined,
    TransportMode.publicTransit => Icons.directions_bus_outlined,
    TransportMode.motorbike || null => Icons.two_wheeler,
  };
}

/// Transports a leg can use (public transit cannot be planned yet).
const legTransportModes = [
  TransportMode.walking,
  TransportMode.motorbike,
  TransportMode.car,
];

Future<TransportMode?> showTransportModeSheet(
  BuildContext context, {
  TransportMode? current,
}) => showModalBottomSheet<TransportMode>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Đổi phương tiện cho chặng này',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final mode in legTransportModes)
          ListTile(
            leading: Icon(ItineraryLegRow._icon(mode)),
            title: Text(transportLabel(mode)),
            trailing: mode == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(mode),
          ),
      ],
    ),
  ),
);
