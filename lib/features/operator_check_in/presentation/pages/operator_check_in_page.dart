import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_camera_scanner_view.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_departure_header.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_manual_code_dialog.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_recent_scans_card.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_result_banner.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Screen #88: Check In Traveler by QR Code (TM-89 / UC-43)
class OperatorCheckInPage extends StatefulWidget {
  const OperatorCheckInPage({
    this.initialScheduleId,
    this.scannerBuilder,
    super.key,
  });

  final int? initialScheduleId;
  final Widget Function(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  })? scannerBuilder;

  @override
  State<OperatorCheckInPage> createState() => _OperatorCheckInPageState();
}

class _OperatorCheckInPageState extends State<OperatorCheckInPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          context.read<OperatorCheckInCubit>().loadInitial(
                preselectedScheduleId: widget.initialScheduleId,
              ),
        );
      }
    });
  }

  Future<void> _openManualEntryDialog() async {
    final code = await CheckInManualCodeDialog.show(context);
    if (code != null && code.isNotEmpty && mounted) {
      await context.read<OperatorCheckInCubit>().submitScan(bookingCode: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Check-in',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.ink),
            tooltip: 'Refresh departures',
            onPressed: () {
              final state = context.read<OperatorCheckInCubit>().state;
              final selectedId = state is OperatorCheckInLoaded
                  ? state.selectedDeparture?.scheduleId
                  : widget.initialScheduleId;
              unawaited(
                context
                    .read<OperatorCheckInCubit>()
                    .loadInitial(preselectedScheduleId: selectedId),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<OperatorCheckInCubit, OperatorCheckInState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is OperatorCheckInLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is OperatorCheckInError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 54,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Retry',
                      minimumHeight: 44,
                      onPressed: () {
                        unawaited(
                          context.read<OperatorCheckInCubit>().loadInitial(
                                preselectedScheduleId: widget.initialScheduleId,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is OperatorCheckInLoaded) {
            if (state.departures.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy_outlined,
                        size: 56,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'No departures scheduled for today',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Check back when a tour departure is active.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Refresh',
                        minimumHeight: 44,
                        onPressed: () {
                          unawaited(
                            context.read<OperatorCheckInCubit>().loadInitial(
                                  preselectedScheduleId:
                                      widget.initialScheduleId,
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            final progress = state.progress ??
                (state.selectedDeparture != null
                    ? DepartureProgress(
                        scheduleId: state.selectedDeparture!.scheduleId,
                        tourTitle: state.selectedDeparture!.tourTitle,
                        startAtUtc: state.selectedDeparture!.startAtUtc,
                        endAtUtc: state.selectedDeparture!.endAtUtc,
                        meetingPoint: state.selectedDeparture!.meetingPoint,
                        checkedInParticipants:
                            state.selectedDeparture!.checkedInParticipants,
                        totalEligibleParticipants:
                            state.selectedDeparture!.totalEligibleParticipants,
                        waitingParticipants:
                            state.selectedDeparture!.waitingParticipants,
                      )
                    : null);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.departures.length > 1) ...[
                    _buildDepartureDropdown(context, state),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (progress != null) ...[
                    CheckInDepartureHeader(progress: progress),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (state.lastResult != null || state.lastFailure != null) ...[
                    CheckInResultBanner(
                      result: state.lastResult,
                      failure: state.lastFailure,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  CheckInCameraScannerView(
                    scannerBuilder: widget.scannerBuilder,
                    isPaused: state.isSubmittingScan,
                    onScanned: (raw) {
                      unawaited(
                        context
                            .read<OperatorCheckInCubit>()
                            .submitScan(qrContent: raw),
                      );
                    },
                  ),
                  if (state.recentScans.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CheckInRecentScansCard(scans: state.recentScans),
                  ],
                  const SizedBox(height: 80), // Space for floating bottom actions
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      bottomSheet: BlocBuilder<OperatorCheckInCubit, OperatorCheckInState>(
        builder: (context, state) {
          if (state is! OperatorCheckInLoaded || state.departures.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: AppColors.line),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Scan next traveler',
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        size: 18,
                        color: Colors.white,
                      ),
                      minimumHeight: 46,
                      onPressed: () {
                        context.read<OperatorCheckInCubit>().clearActiveBanner();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Manual code',
                      isOutlined: true,
                      icon: const Icon(
                        Icons.keyboard_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      minimumHeight: 46,
                      onPressed: () {
                        unawaited(_openManualEntryDialog());
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepartureDropdown(
    BuildContext context,
    OperatorCheckInLoaded state,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: state.selectedDeparture?.scheduleId,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.ink),
          items: state.departures.map((departure) {
            final startLocal = departure.startAtUtc.toLocal();
            final timeStr =
                '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
            return DropdownMenuItem<int>(
              value: departure.scheduleId,
              child: Text(
                '$timeStr · ${departure.tourTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            );
          }).toList(),
          onChanged: (scheduleId) {
            if (scheduleId != null) {
              unawaited(
                context
                    .read<OperatorCheckInCubit>()
                    .selectDeparture(scheduleId),
              );
            }
          },
        ),
      ),
    );
  }
}
