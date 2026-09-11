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
/// Output: navigates back (context.pop) on success after brief success display.
class CreateTravelGroupPage extends StatefulWidget {
  const CreateTravelGroupPage({
    super.key,
    this.itineraryId,
    this.itineraryTitle,
  });

  final int? itineraryId;
  final String? itineraryTitle;

  @override
  State<CreateTravelGroupPage> createState() => _CreateTravelGroupPageState();
}

class _CreateTravelGroupPageState extends State<CreateTravelGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _itineraryController;
  int? _selectedItineraryId;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _selectedItineraryId = widget.itineraryId;
    _itineraryController = TextEditingController(
      text:
          widget.itineraryTitle ??
          (widget.itineraryId != null
              ? 'Itinerary #${widget.itineraryId}'
              : ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itineraryController.dispose();
    super.dispose();
  }

  Future<void> _showItineraryPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Select Itinerary',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Chuyến đi Đà Nẵng 4N3D'),
                subtitle: const Text('Itinerary ID: 1'),
                onTap: () => Navigator.of(ctx).pop(1),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Enter custom Itinerary ID...'),
                onTap: () => Navigator.of(ctx).pop(-1),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    if (selected == -1) {
      final customId = await _showManualIdDialog();
      if (customId != null && mounted) {
        setState(() {
          _selectedItineraryId = customId;
          _itineraryController.text = 'Itinerary #$customId';
        });
      }
    } else {
      setState(() {
        _selectedItineraryId = selected;
        _itineraryController.text = 'Chuyến đi Đà Nẵng 4N3D (ID: 1)';
      });
    }
  }

  Future<int?> _showManualIdDialog() async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Itinerary ID'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Itinerary ID',
            hintText: 'e.g. 1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
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
                      // Itinerary picker field (BR-41)
                      AppTextField(
                        label: 'Itinerary',
                        controller: _itineraryController,
                        enabled: !isDisabled,
                        readOnly: true,
                        onTap: isDisabled ? null : _showItineraryPicker,
                        helperText: 'Tap to select linked itinerary',
                        suffix: const Icon(Icons.arrow_drop_down),
                        validator: (_) {
                          if (_selectedItineraryId == null ||
                              _selectedItineraryId! <= 0) {
                            return 'Please select an itinerary.';
                          }
                          return null;
                        },
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
                                    itineraryId: _selectedItineraryId!,
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
