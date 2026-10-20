import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_stop.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

/// One place on a tour day: planned time, name, address, stay and notes.
class ItineraryStopTile extends StatelessWidget {
  const ItineraryStopTile({required this.stop, super.key});

  final TourItineraryStop stop;

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: TourSearchPalette.teal,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.poiName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: TourSearchPalette.navy,
                  ),
                ),
                if (address != null && address.isNotEmpty)
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TourSearchPalette.muted,
                    ),
                  ),
                if (stay != null && stay > 0)
                  Text(
                    TourDetailStrings.stayLine(tripDuration(stay)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                if (notes != null && notes.isNotEmpty)
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
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
