import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

class TripHistoryFiltersBar extends StatelessWidget {
  const TripHistoryFiltersBar({
    required this.selectedTripType,
    required this.startDate,
    required this.endDate,
    required this.onTripTypeChanged,
    required this.onDateRangeSelected,
    required this.onClearFilters,
    this.validationError,
    super.key,
  });

  final TripRecordTypeFilter selectedTripType;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<TripRecordTypeFilter> onTripTypeChanged;
  final void Function(DateTime? start, DateTime? end) onDateRangeSelected;
  final VoidCallback onClearFilters;
  final String? validationError;

  bool get hasActiveFilters =>
      selectedTripType != TripRecordTypeFilter.all ||
      startDate != null ||
      endDate != null;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final hasDate = startDate != null || endDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (validationError != null && validationError!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.errorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: p.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    validationError!,
                    style: TextStyle(
                      color: p.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (type, label) in const [
                (TripRecordTypeFilter.all, TripHistoryStringsEn.filterAll),
                (
                  TripRecordTypeFilter.tourBooking,
                  TripHistoryStringsEn.filterTour,
                ),
                (
                  TripRecordTypeFilter.selfPlannedItinerary,
                  TripHistoryStringsEn.filterItinerary,
                ),
              ]) ...[
                ChoiceChip(
                  label: Text(label),
                  selected: selectedTripType == type,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: p.surface,
                  selectedColor: p.softAccent,
                  side: BorderSide(
                    color: selectedTripType == type ? p.softAccent : p.border,
                  ),
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedTripType == type
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selectedTripType == type ? p.primary : p.secondary,
                  ),
                  onSelected: (selected) {
                    if (selected) onTripTypeChanged(type);
                  },
                ),
                const SizedBox(width: 6),
              ],

              const SizedBox(width: 4),

              ActionChip(
                avatar: Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: hasDate ? p.primary : p.secondary,
                ),
                label: Text(
                  startDate != null && endDate != null
                      ? '${TripFormatters.formatVietnamDate(startDate!)} – ${TripFormatters.formatVietnamDate(endDate!)}'
                      : TripHistoryStringsEn.filterDateRange,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                    color: hasDate ? p.primary : p.ink,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                labelPadding: const EdgeInsets.only(right: 6),
                backgroundColor: hasDate ? p.softAccent : p.surface,
                side: BorderSide(color: hasDate ? p.softAccent : p.border),
                shape: const StadiumBorder(),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 2),
                    initialDateRange: startDate != null && endDate != null
                        ? DateTimeRange(start: startDate!, end: endDate!)
                        : null,
                  );
                  if (picked != null) {
                    onDateRangeSelected(picked.start, picked.end);
                  }
                },
              ),

              if (hasActiveFilters) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onClearFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: p.primary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    TripHistoryStringsEn.filterReset,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
