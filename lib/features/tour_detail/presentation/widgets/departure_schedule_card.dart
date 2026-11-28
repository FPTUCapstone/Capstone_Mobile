import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/formatters/tour_detail_formatters.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

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
    final c = context.tmColors;
    final selectable = schedule.isSelectable;
    final window = formatDepartureWindow(
      schedule.departureAtUtc,
      schedule.endAtUtc,
    );
    final state = departureStateLabel(schedule);
    final muted = selectable ? null : c.textMuted;
    final accent = selectable ? c.brandTeal : c.error;
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
        label: [
          window,
          state,
          formatVnd(schedule.price),
          if (childPrice != null)
            TourDetailStrings.childPriceLine(
              childPrice == 0 ? TourDetailStrings.free : formatVnd(childPrice),
            ),
          if (infantPrice != null)
            TourDetailStrings.infantPriceLine(
              infantPrice == 0
                  ? TourDetailStrings.free
                  : formatVnd(infantPrice),
            ),
          if (meetingPoint != null && meetingPoint.isNotEmpty)
            TourDetailStrings.meetingPointLine(meetingPoint),
          if (deadline != null)
            TourDetailStrings.registrationClosesLine(
              formatVietnamDateTime(deadline),
            ),
        ].join(', '),
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: isSelected
              ? (selectable ? c.tealSoftContainer : c.errorContainer)
              : c.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TripMateRadius.sm),
            side: BorderSide(
              color: isSelected ? accent : c.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
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
                        color: isSelected ? accent : c.textMuted,
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
                              color: muted ?? c.textPrimary,
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
                                style: AppTypography.price(
                                  muted ?? c.brandTeal,
                                  fontSize: 13.5,
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
    final c = context.tmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selectable ? c.successContainer : c.errorContainer,
        borderRadius: BorderRadius.circular(TripMateRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.uiFont,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selectable ? c.success : c.error,
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
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: TextStyle(fontSize: 12, color: c.textSecondary)),
    );
  }
}
