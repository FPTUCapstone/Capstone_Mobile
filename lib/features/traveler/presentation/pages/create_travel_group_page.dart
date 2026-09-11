import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
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
  });

  final int itineraryId;
  final String itineraryTitle;

  @override
  State<CreateTravelGroupPage> createState() => _CreateTravelGroupPageState();
}

class _CreateTravelGroupPageState extends State<CreateTravelGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _itineraryController;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _itineraryController = TextEditingController(text: widget.itineraryTitle);
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
            setState(() => _nameError = state.errorMessage);
          case CreateTravelGroupStatus.initial:
            // returned from validationFailure; error already shown
            break;
          case CreateTravelGroupStatus.success:
            setState(() => _nameError = null);
            final group = state.result;
            final router = GoRouter.maybeOf(context);
            if (group != null && router != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Travel group created successfully! You are the Group Host.',
                  ),
                ),
              );
              Future<void>.delayed(const Duration(milliseconds: 800), () {
                if (!context.mounted) return;
                router.goNamed(
                  AppRouteNames.travelGroupDetails,
                  pathParameters: {'groupId': group.id.toString()},
                  extra: group,
                );
              });
            }
          case CreateTravelGroupStatus.failure:
            setState(() => _nameError = null);
          case CreateTravelGroupStatus.submitting:
            setState(() => _nameError = null);
        }
      },
      builder: (context, state) {
        final isSubmitting = state.status == CreateTravelGroupStatus.submitting;
        final isSuccess = state.status == CreateTravelGroupStatus.success;
        final isDisabled = isSubmitting || isSuccess;

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
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Group Name field — uses validator for inline error
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
                        helperText: 'Selected eligible itinerary',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'You will become the Group Host for this travel group.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
