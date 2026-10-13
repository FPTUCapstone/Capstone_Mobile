import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_state.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/star_rating_selector.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

class TripReviewPage extends StatefulWidget {
  const TripReviewPage({
    required this.trip,
    this.travelerId = 1,
    this.referenceTime,
    super.key,
  });

  final TripHistoryItem trip;
  final int travelerId;
  final DateTime? referenceTime;

  @override
  State<TripReviewPage> createState() => _TripReviewPageState();
}

class _TripReviewPageState extends State<TripReviewPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<TripReviewCubit>();
      cubit.initialize(
        trip: widget.trip,
        travelerId: widget.travelerId,
        referenceTime: widget.referenceTime,
      );

      final state = cubit.state;
      if (state.title.isNotEmpty) {
        _titleController.text = state.title;
      }
      if (state.content.isNotEmpty) {
        _contentController.text = state.content;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showAddPhotoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TripHistoryStringsEn.photoPickMockTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.image, color: AppColors.primary),
                title: const Text(TripHistoryStringsEn.photoValidSample),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.read<TripReviewCubit>().addPhoto(
                    const TripReviewPhotoAttachment(
                      name: 'sample_photo.jpg',
                      sizeBytes: 2202010,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning, color: AppColors.warning),
                title: const Text(TripHistoryStringsEn.photoOversizedSample),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.read<TripReviewCubit>().addPhoto(
                    const TripReviewPhotoAttachment(
                      name: 'large_panorama.jpg',
                      sizeBytes: 6710886, // Exceeds 5MB
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripReviewCubit, TripReviewState>(
      listener: (context, state) {
        if (state.title.isNotEmpty && _titleController.text != state.title) {
          _titleController.text = state.title;
        }
        if (state.content.isNotEmpty &&
            _contentController.text != state.content) {
          _contentController.text = state.content;
        }

        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.successMessage ??
                    TripHistoryStringsEn.reviewSubmitSuccess,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TripReviewCubit>();
        final trip = state.trip ?? widget.trip;

        final pageTitle = state.isReadOnly
            ? TripHistoryStringsEn.viewReviewTitle
            : (state.isEdit
                  ? TripHistoryStringsEn.editReviewTitle
                  : TripHistoryStringsEn.tripReviewTitle);

        final submitButtonText = state.isEdit
            ? TripHistoryStringsEn.actionSaveReview
            : TripHistoryStringsEn.actionSubmitReview;

        return Scaffold(
          appBar: AppBar(title: Text(pageTitle)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Trip Information Summary Area
                Card(
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.flight_takeoff,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              TripHistoryStringsEn.summarySectionTitle,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          trip.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Text(
                              '${TripHistoryStringsEn.labelDepartureDate}: ',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                TripFormatters.formatVietnamDate(
                                  trip.departureDate,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            Text(
                              '${TripHistoryStringsEn.labelBookingCode}: ',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                trip.bookingCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Status Banners (Read-only, Edit Window, Errors)
                if (state.isReadOnly) ...[
                  const AppAlert(
                    message: TripHistoryStringsEn.reviewReadOnlyNotice,
                    type: AppAlertType.info,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else if (state.isEdit) ...[
                  const AppAlert(
                    message: TripHistoryStringsEn.reviewEditWindowActive,
                    type: AppAlertType.info,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                if (state.generalError != null) ...[
                  AppAlert(
                    message: state.generalError!,
                    type: AppAlertType.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 3. Rating Control (1 to 5 stars, BR-93)
                Text(
                  TripHistoryStringsEn.ratingSectionTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                StarRatingSelector(
                  rating: state.rating,
                  isReadOnly: state.isReadOnly,
                  errorText: state.ratingError,
                  onRatingChanged: cubit.setRating,
                ),
                const SizedBox(height: AppSpacing.md),

                // 4. Review Title Input
                Text(
                  TripHistoryStringsEn.reviewTitleLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _titleController,
                  enabled: !state.isReadOnly,
                  decoration: InputDecoration(
                    hintText: TripHistoryStringsEn.reviewTitleHint,
                    errorText: state.titleError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: cubit.setTitle,
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Review Content Input
                Text(
                  TripHistoryStringsEn.reviewContentLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _contentController,
                  enabled: !state.isReadOnly,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: TripHistoryStringsEn.reviewContentHint,
                    errorText: state.contentError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: cubit.setContent,
                ),
                const SizedBox(height: AppSpacing.md),

                // 6. Photo Attachments Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TripHistoryStringsEn.photoSectionTitle,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            TripHistoryStringsEn.photoSectionSubtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (!state.isReadOnly && state.photos.length < 5) ...[
                      const SizedBox(width: AppSpacing.xs),
                      OutlinedButton.icon(
                        onPressed: () => _showAddPhotoSheet(context),
                        icon: const Icon(Icons.add_a_photo, size: 16),
                        label: const Text(TripHistoryStringsEn.actionAddPhoto),
                      ),
                    ],
                  ],
                ),
                if (state.photoError != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    state.photoError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),

                // Photos List Preview
                if (state.photos.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: List.generate(state.photos.length, (index) {
                      final photo = state.photos[index];
                      return Chip(
                        avatar: const Icon(Icons.image, size: 16),
                        label: Text(
                          photo.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: state.isReadOnly
                            ? null
                            : () => cubit.removePhoto(index),
                        deleteIcon: const Icon(Icons.close, size: 14),
                      );
                    }),
                  ),
                const SizedBox(height: AppSpacing.xl),

                // 7. Buttons: Submit & Cancel
                if (!state.isReadOnly) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: state.isSubmitting ? null : cubit.submit,
                      child: state.isSubmitting
                          ? const LoadingIndicator()
                          : Text(submitButtonText),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(TripHistoryStringsEn.actionCancel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
