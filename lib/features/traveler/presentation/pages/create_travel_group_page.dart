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
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
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
    final c = context.tmColors;
    return BlocConsumer<CreateTravelGroupCubit, CreateTravelGroupState>(
      listener: (context, state) {
        switch (state.status) {
          case CreateTravelGroupStatus.validationFailure:
            final error = state.errorMessage;
            if (error == 'Vui lòng chọn một lịch trình.') {
              setState(() {
                _itineraryError = error;
                _nameError = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error ?? 'Vui lòng chọn một lịch trình.'),
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
            break;
          case CreateTravelGroupStatus.success:
            setState(() {
              _nameError = null;
              _itineraryError = null;
            });
            final group = state.result;
            final router = GoRouter.maybeOf(context);
            if (group != null && router != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Tạo nhóm du lịch thành công! Bạn là Trưởng nhóm.',
                  ),
                  backgroundColor: c.success,
                  duration: const Duration(seconds: 3),
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
              title: 'Tạo nhóm du lịch',
              content: [
                if (state.status == CreateTravelGroupStatus.failure) ...[
                  AppAlert(
                    message:
                        state.errorMessage ??
                        'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
                    type: AppAlertType.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (isSuccess) ...[
                  const AppAlert(
                    message: 'Tạo nhóm du lịch thành công! Bạn là Trưởng nhóm.',
                    type: AppAlertType.success,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (hasMeta) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c.tealSoftContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.map_outlined,
                                size: 18,
                                color: c.brandTeal,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.itineraryTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: c.textPrimary,
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
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: c.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  widget.destination!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
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
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 15,
                                color: c.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                widget.dateRange!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.textSecondary,
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
                AppSectionCard(
                  title: 'Thông tin nhóm',
                  icon: Icons.groups_outlined,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'Tên nhóm',
                          controller: _nameController,
                          enabled: !isDisabled,
                          validator: (val) {
                            if (_nameError != null) return _nameError;
                            if (val == null || val.trim().isEmpty) {
                              return 'Trường này là bắt buộc.';
                            }
                            if (val.trim().length > 150) {
                              return 'Tên nhóm không được vượt quá 150 ký tự.';
                            }
                            return null;
                          },
                          helperText: 'Tối đa 150 ký tự',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Lịch trình',
                          controller: _itineraryController,
                          enabled: !isDisabled,
                          readOnly: true,
                          validator: (_) => _itineraryError,
                          helperText: 'Lịch trình hợp lệ đã chọn',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: c.tealSoftContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: c.brandTeal.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                size: 18,
                                color: c.brandTeal,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Bạn sẽ trở thành Trưởng nhóm của nhóm du lịch này.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.brandTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Tạo nhóm',
                  onPressed: isDisabled
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            context.read<CreateTravelGroupCubit>().submit(
                              name: _nameController.text,
                              itineraryId: widget.itineraryId,
                            );
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
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
                  child: const Text('Hủy'),
                ),
              ],
            ),
            if (isSubmitting)
              ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(color: c.brandTeal),
                ),
              ),
          ],
        );
      },
    );
  }
}
