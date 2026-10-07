import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

class StarRatingSelector extends StatelessWidget {
  const StarRatingSelector({
    required this.rating,
    this.onRatingChanged,
    this.isReadOnly = false,
    this.errorText,
    super.key,
  });

  final int? rating;
  final ValueChanged<int>? onRatingChanged;
  final bool isReadOnly;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final currentRating = rating ?? 0;
    final effectiveReadOnly = isReadOnly || onRatingChanged == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: rating == null
              ? TripHistoryStringsEn.ratingPrompt
              : TripHistoryStringsEn.a11ySelectedRating.replaceAll(
                  '{rating}',
                  rating.toString(),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final isFilled = starNumber <= currentRating;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: InkResponse(
                  onTap: effectiveReadOnly
                      ? null
                      : () => onRatingChanged!(starNumber),
                  radius: 24,
                  child: Semantics(
                    button: !effectiveReadOnly,
                    enabled: !effectiveReadOnly,
                    label: TripHistoryStringsEn.a11yStarRating.replaceAll(
                      '{star}',
                      starNumber.toString(),
                    ),
                    selected: isFilled,
                    child: Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 38,
                      color: isFilled ? AppColors.warning : AppColors.muted,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
