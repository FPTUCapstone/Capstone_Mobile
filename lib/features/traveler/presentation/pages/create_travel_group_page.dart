import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/travel_group_details_route_args.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

/// Page for UC-17 Create Travel Group.
///
/// Input: [CreateTravelGroupCubit] provided by router via BlocProvider.
/// Output: shows MSG54 and opens the newly created travel group on success.
class CreateTravelGroupPage extends StatefulWidget {
  const CreateTravelGroupPage({
    super.key,
    required this.itineraryId,
    required this.itineraryTitle,
    this.destination,
    this.dateRange,
  });

  final int itineraryId;
  final String itineraryTitle;
  final String? destination;
  final String? dateRange;

  @override
  State<CreateTravelGroupPage> createState() => _CreateTravelGroupPageState();
}

class _CreateTravelGroupPageState extends State<CreateTravelGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _itineraryController;
  String? _nameError;
  String? _itineraryError;

  @override
  void initState() {
    super.initState();
    _itineraryController = TextEditingController(text: widget.itineraryTitle);
    _nameController.addListener(() {
      if (_nameError != null) {
        setState(() => _nameError = null);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itineraryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateTravelGroupCubit, CreateTravelGroupState>(
      listener: (context, state) {
        switch (state.status) {
          case CreateTravelGroupStatus.validationFailure:
            final error = state.errorMessage;
            if (error == 'Please select an itinerary.') {
              setState(() {
                _itineraryError = error;
                _nameError = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error ?? 'Please select an itinerary.'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else {
              setState(() {
                _nameError = error;
                _itineraryError = null;
              });
            }
            _formKey.currentState?.validate();
          case CreateTravelGroupStatus.initial:
            // returned from validationFailure; error already shown
            break;
          case CreateTravelGroupStatus.success:
            setState(() {
              _nameError = null;
              _itineraryError = null;
            });
            final group = state.result;
            final router = GoRouter.maybeOf(context);
            if (group != null && router != null) {
              // MSG54: Travel group created successfully! You are the Group Host.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Travel group created successfully! You are the Group Host.',
                  ),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 3),
                ),
              );
              Future<void>.delayed(const Duration(milliseconds: 500), () {
                if (!context.mounted) return;
                router.goNamed(
                  AppRouteNames.travelGroupDetails,
                  pathParameters: {'groupId': group.id.toString()},
                  extra: TravelGroupDetailsRouteArgs(
                    group: group,
                    isHost: true,
                  ),
                );
              });
            }
          case CreateTravelGroupStatus.failure:
            setState(() {
              _nameError = null;
              _itineraryError = null;
            });
          case CreateTravelGroupStatus.submitting:
            setState(() {
              _nameError = null;
              _itineraryError = null;
            });
        }
      },
      builder: (context, state) {
        final isSubmitting = state.status == CreateTravelGroupStatus.submitting;
        final isSuccess = state.status == CreateTravelGroupStatus.success;
        final isDisabled = isSubmitting || isSuccess;

        final hasMeta =
            (widget.destination != null && widget.destination!.isNotEmpty) ||
            (widget.dateRange != null && widget.dateRange!.isNotEmpty);

        return Stack(
          children: [
            AppPageScaffold(
              title: 'Create Travel Group',
              content: [
                // Server error banner
                if (state.status == CreateTravelGroupStatus.failure) ...[
                  AppAlert(
                    message:
                        state.errorMessage ??
                        'TripMate is temporarily unable to process your request. Please check your connection and try again.',
                    type: AppAlertType.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Success banner
                if (isSuccess) ...[
                  const AppAlert(
                    message:
                        'Travel group created successfully! You are the Group Host.',
                    type: AppAlertType.success,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Read-only itinerary summary card (SRS 3.4.1)
                if (hasMeta) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                widget.itineraryTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (widget.destination != null &&
                            widget.destination!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  widget.destination!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.dateRange != null &&
                            widget.dateRange!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 15,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                widget.dateRange!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Group Name field (SRS 3.4.1) — uses validator for inline error
                      AppTextField(
                        label: 'Group Name',
                        controller: _nameController,
                        enabled: !isDisabled,
                        validator: (val) {
                          if (_nameError != null) return _nameError;
                          if (val == null || val.trim().isEmpty) {
                            return 'This field is required.';
                          }
                          if (val.trim().length > 150) {
                            return 'Group name must not exceed 150 characters.';
                          }
                          return null;
                        },
                        helperText: 'Max 150 characters',
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Selected itinerary association (BR-41)
                      AppTextField(
                        label: 'Itinerary',
                        controller: _itineraryController,
                        enabled: !isDisabled,
                        readOnly: true,
                        validator: (_) => _itineraryError,
                        helperText: 'Selected eligible itinerary',
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Host role notice (BR-42)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'You will become the Group Host for this travel group.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Primary Action: [Create Group] (SRS 3.4.1)
                      AppButton(
                        label: 'Create Group',
                        onPressed: isDisabled
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  context.read<CreateTravelGroupCubit>().submit(
                                    name: _nameController.text,
                                    itineraryId: widget.itineraryId,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Secondary Action: [Cancel] (SRS 3.4.1)
                      OutlinedButton(
                        key: const Key('cancel_button'),
                        onPressed: isDisabled
                            ? null
                            : () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(AppRoutes.traveler);
                                }
                              },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Full-screen loading overlay
            if (isSubmitting)
              const ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}
