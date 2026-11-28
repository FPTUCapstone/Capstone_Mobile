import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/formatters/check_in_time_format.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_camera_scanner_view.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_departure_header.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_manual_code_dialog.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_recent_scans_card.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_result_banner.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sticky_action_bar.dart';

/// Screen #88: Check In Traveler by QR Code (TM-89 / UC-43)
class OperatorCheckInPage extends StatefulWidget {
  const OperatorCheckInPage({
    this.initialScheduleId,
    this.scannerController,
    this.scannerBuilder,
    super.key,
  });

  final int? initialScheduleId;
  final MobileScannerController? scannerController;
  final Widget Function(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  })?
  scannerBuilder;

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
    final cubit = context.read<OperatorCheckInCubit>();
    if (!cubit.beginManualEntry()) return;
    try {
      final code = await CheckInManualCodeDialog.show(context);
      if (code != null && code.isNotEmpty && mounted) {
        await cubit.submitScan(bookingCode: code);
      }
    } finally {
      cubit.endManualEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final current = context.watch<OperatorCheckInCubit>().state;
    final scanInFlight =
        current is OperatorCheckInLoaded &&
        (current.isSubmittingScan ||
            current.isManualEntryActive ||
            current.isRefreshing);
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppCoastalAppBar(
        title: 'Điểm danh',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới danh sách khởi hành',
            onPressed: scanInFlight
                ? null
                : () {
                    unawaited(
                      context.read<OperatorCheckInCubit>().loadInitial(
                        preselectedScheduleId: current is OperatorCheckInLoaded
                            ? null
                            : widget.initialScheduleId,
                      ),
                    );
                  },
          ),
        ],
      ),
      body: BlocConsumer<OperatorCheckInCubit, OperatorCheckInState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is OperatorCheckInLoading) {
            return Center(child: CircularProgressIndicator(color: c.brandTeal));
          }

          if (state is OperatorCheckInError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: c.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 32,
                        color: c.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Thử lại',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.tealSoftContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.event_busy_outlined,
                          size: 32,
                          color: c.brandTeal,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Không có chuyến khởi hành nào hôm nay',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Quay lại khi có lịch khởi hành đang diễn ra.',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Làm mới',
                        minimumHeight: 44,
                        onPressed: () {
                          unawaited(
                            context.read<OperatorCheckInCubit>().loadInitial(),
                          );
                        },
                      ),
                      if (state.lastResult != null || state.lastFailure != null)
                        CheckInResultBanner(
                          result: state.lastResult,
                          failure: state.lastFailure,
                        ),
                      CheckInRecentScansCard(scans: state.recentScans),
                    ],
                  ),
                ),
              );
            }

            final progress =
                state.progress ??
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
                  if (state.departures.length > 1 ||
                      state.selectedDeparture == null) ...[
                    _buildDepartureDropdown(context, state),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (progress != null) ...[
                    CheckInDepartureHeader(progress: progress),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (state.lastResult != null ||
                      state.lastFailure != null) ...[
                    CheckInResultBanner(
                      result: state.lastResult,
                      failure: state.lastFailure,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  CheckInCameraScannerView(
                    key: const ValueKey('check-in-camera'),
                    controller: widget.scannerController,
                    scannerBuilder: widget.scannerBuilder,
                    scanSession: state.scanSession,
                    canScan: () =>
                        context.read<OperatorCheckInCubit>().canScanQr,
                    isPaused:
                        state.selectedDeparture == null ||
                        state.isSubmittingScan ||
                        !state.scanArmed ||
                        state.isManualEntryActive ||
                        state.isRefreshing,
                    onScanned: (raw) {
                      unawaited(
                        context.read<OperatorCheckInCubit>().submitScan(
                          qrContent: raw,
                        ),
                      );
                    },
                  ),
                  if (state.recentScans.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CheckInRecentScansCard(scans: state.recentScans),
                  ],
                  const SizedBox(height: 80),
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

          return AppStickyActionBar(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Quét khách tiếp theo',
                    icon: Icon(
                      Icons.qr_code_scanner,
                      size: 18,
                      color: c.textOnBrand,
                    ),
                    minimumHeight: 46,
                    onPressed:
                        state.selectedDeparture == null ||
                            state.isSubmittingScan ||
                            state.isManualEntryActive ||
                            state.isRefreshing
                        ? null
                        : () {
                            context
                                .read<OperatorCheckInCubit>()
                                .clearActiveBanner();
                          },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Nhập mã thủ công',
                    isOutlined: true,
                    icon: Icon(
                      Icons.keyboard_outlined,
                      size: 18,
                      color: c.brandTeal,
                    ),
                    minimumHeight: 46,
                    onPressed:
                        state.selectedDeparture == null ||
                            state.isSubmittingScan ||
                            state.isManualEntryActive ||
                            state.isRefreshing
                        ? null
                        : () {
                            unawaited(_openManualEntryDialog());
                          },
                  ),
                ),
              ],
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
    final c = context.tmColors;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: state.selectedDeparture?.scheduleId,
          isExpanded: true,
          hint: const Text('Chọn chuyến khởi hành'),
          icon: Icon(Icons.arrow_drop_down, color: c.textPrimary),
          items: state.departures.map((departure) {
            final timeStr = CheckInTimeFormat.dateTime(departure.startAtUtc);
            return DropdownMenuItem<int>(
              value: departure.scheduleId,
              child: Text(
                '$timeStr · ${departure.tourTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged:
              state.isSubmittingScan ||
                  state.isManualEntryActive ||
                  state.isRefreshing
              ? null
              : (scheduleId) {
                  if (scheduleId != null) {
                    unawaited(
                      context.read<OperatorCheckInCubit>().selectDeparture(
                        scheduleId,
                      ),
                    );
                  }
                },
        ),
      ),
    );
  }
}
