import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_stop.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';

/// One place on a tour day: planned time, name, address, stay and notes.
class ItineraryStopTile extends StatelessWidget {
  const ItineraryStopTile({required this.stop, super.key});

  final TourItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final stay = stop.stayMinutes;
    final address = stop.address?.trim();
    final notes = stop.notes?.trim();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              stop.plannedTime ?? '–',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: c.brandTeal,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.poiName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                if (address != null && address.isNotEmpty)
                  Text(
                    address,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                if (stay != null && stay > 0)
                  Text(
                    TourDetailStrings.stayLine(tripDuration(stay)),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                if (notes != null && notes.isNotEmpty)
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
