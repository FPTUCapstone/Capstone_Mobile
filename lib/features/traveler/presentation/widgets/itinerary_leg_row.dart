import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
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
    final palette = CoastalPalette.of(context);
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
      padding: const EdgeInsets.only(left: 36, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon(mode), size: 15, color: palette.secondary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        summary,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onChangeMode != null)
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: palette.softAccent,
                    foregroundColor: palette.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
          if (showWalkHint)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 3),
              child: Text(
                'Gần, có thể đi bộ ~${walkingMinutes(meters)} phút',
                style: TextStyle(fontSize: 11, color: palette.secondary),
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
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
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
