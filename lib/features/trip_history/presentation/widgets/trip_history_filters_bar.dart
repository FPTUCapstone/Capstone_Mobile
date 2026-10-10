import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
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

  final TripType? selectedTripType;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<TripType?> onTripTypeChanged;
  final void Function(DateTime? start, DateTime? end) onDateRangeSelected;
  final VoidCallback onClearFilters;
  final String? validationError;

  bool get hasActiveFilters =>
      selectedTripType != null || startDate != null || endDate != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error banner if date range is invalid (MSG29)
        if (validationError != null && validationError!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    validationError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Filter chips bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              // Date Range Button
              ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 16),
                label: Text(
                  startDate != null && endDate != null
                      ? '${TripFormatters.formatVietnamDate(startDate!)} - ${TripFormatters.formatVietnamDate(endDate!)}'
                      : TripHistoryStringsEn.filterDateRange,
                ),
                backgroundColor: startDate != null || endDate != null
                    ? AppColors.primarySoft
                    : null,
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
              const SizedBox(width: AppSpacing.xs),

              // Trip Type: All
              ChoiceChip(
                label: const Text(TripHistoryStringsEn.filterAll),
                selected: selectedTripType == null,
                onSelected: (selected) {
                  if (selected) onTripTypeChanged(null);
                },
              ),
              const SizedBox(width: AppSpacing.xxs),

              // Trip Type: Tour
              ChoiceChip(
                label: const Text(TripHistoryStringsEn.filterTour),
                selected: selectedTripType == TripType.tour,
                onSelected: (selected) {
                  onTripTypeChanged(selected ? TripType.tour : null);
                },
              ),
              const SizedBox(width: AppSpacing.xxs),

              // Trip Type: Commercial Service
              ChoiceChip(
                label: const Text(TripHistoryStringsEn.filterCommercialService),
                selected: selectedTripType == TripType.commercialService,
                onSelected: (selected) {
                  onTripTypeChanged(
                    selected ? TripType.commercialService : null,
                  );
                },
              ),
              const SizedBox(width: AppSpacing.xxs),

              // Trip Type: Itinerary
              ChoiceChip(
                label: const Text(TripHistoryStringsEn.filterItinerary),
                selected: selectedTripType == TripType.itinerary,
                onSelected: (selected) {
                  onTripTypeChanged(selected ? TripType.itinerary : null);
                },
              ),

              if (hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text(TripHistoryStringsEn.filterReset),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
