import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/formatters/tour_detail_formatters.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

/// The state a traveler sees for a departure, taken from what the server knows
/// (sold out, capacity unknown, registration closed) rather than guessed.
String departureStateLabel(TourScheduleItem schedule) {
  if (schedule.isSoldOut) return TourDetailStrings.soldOut;
  final slots = schedule.remainingSlots;
  if (slots == null ||
      schedule.availabilityStatus == AvailabilityStatus.unknown) {
    return TourDetailStrings.capacityUnknown;
  }
  if (schedule.bookable == false) return TourDetailStrings.registrationClosed;
  return TourDetailStrings.remainingSlots(slots);
}

/// One selectable departure. Departures that cannot be booked stay visible and
/// selectable (so the reason is shown) but are muted.
class DepartureScheduleCard extends StatelessWidget {
  const DepartureScheduleCard({
    required this.schedule,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final TourScheduleItem schedule;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectable = schedule.isSelectable;
    final window = formatDepartureWindow(
      schedule.departureAtUtc,
      schedule.endAtUtc,
    );
    final state = departureStateLabel(schedule);
    final muted = selectable ? null : Colors.grey;
    final accent = selectable
        ? const Color(0xFF16A34A)
        : const Color(0xFFEF4444);
    final childPrice = schedule.childPrice;
    final infantPrice = schedule.infantPrice;
    final meetingPoint = schedule.meetingPoint?.trim();
    final deadline = schedule.registrationDeadlineUtc;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        key: Key('schedule-${schedule.scheduleId}'),
        button: true,
        selected: isSelected,
        label: '$window, $state',
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected
                  ? (selectable
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2))
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accent : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: isSelected ? accent : Colors.grey,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        window,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: muted ?? TourSearchPalette.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatVnd(schedule.price),
                            style: TextStyle(
                              fontSize: 13,
                              color: muted ?? TourSearchPalette.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _StateBadge(label: state, selectable: selectable),
                        ],
                      ),
                      if (childPrice != null)
                        _DetailLine(
                          TourDetailStrings.childPriceLine(
                            childPrice == 0
                                ? TourDetailStrings.free
                                : formatVnd(childPrice),
                          ),
                        ),
                      if (infantPrice != null)
                        _DetailLine(
                          TourDetailStrings.infantPriceLine(
                            infantPrice == 0
                                ? TourDetailStrings.free
                                : formatVnd(infantPrice),
                          ),
                        ),
                      if (meetingPoint != null && meetingPoint.isNotEmpty)
                        _DetailLine(
                          TourDetailStrings.meetingPointLine(meetingPoint),
                        ),
                      if (deadline != null)
                        _DetailLine(
                          TourDetailStrings.registrationClosesLine(
                            formatVietnamDateTime(deadline),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.selectable});

  final String label;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selectable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selectable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
      ),
    );
  }
}
