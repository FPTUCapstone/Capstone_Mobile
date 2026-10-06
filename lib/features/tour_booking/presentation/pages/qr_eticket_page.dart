import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_cubit.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_state.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

/// Screen #69 — QR E-ticket View Page (UC-29 View QR E-ticket).
class QrEticketPage extends StatelessWidget {
  const QrEticketPage({
    required this.bookingId,
    this.initialBooking,
    this.isDemoMode = false,
    super.key,
  });

  final String bookingId;
  final TourBookingRecord? initialBooking;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QrEticketCubit(
        bookingId: bookingId,
        initialBooking: initialBooking,
        isDemoMode: isDemoMode,
      )..load(),
      child: _QrEticketView(bookingId: bookingId),
    );
  }
}

class _QrEticketView extends StatelessWidget {
  const _QrEticketView({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<QrEticketCubit>();
    final state = cubit.state;

    return Scaffold(
      backgroundColor: TourSearchPalette.background,
      appBar: AppBar(
        title: const Text('Vé điện tử QR (E-ticket)'),
        backgroundColor: Colors.white,
        foregroundColor: TourSearchPalette.navy,
        elevation: 0,
        leading: IconButton(
          key: const Key('eticket-appbar-back-button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Trở về',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: SafeArea(
        child: switch (state.status) {
          QrEticketStatus.initial || QrEticketStatus.loading => const Center(
            child: CircularProgressIndicator(color: TourSearchPalette.teal),
          ),
          QrEticketStatus.error => _EticketErrorView(
            message: state.errorMessage ?? QrEticketState.msg127,
            onRetry: cubit.load,
          ),
          QrEticketStatus.pendingIntegration => _EticketPendingView(
            bookingId: bookingId,
          ),
          QrEticketStatus.unauthorized => _EticketBlockedView(
            icon: Icons.lock_outline,
            message: state.statusMessage ?? QrEticketState.msg126,
            messageKey: const Key('eticket-unauthorized-message'),
            isDemoMode: state.isDemoMode,
            onResetDemo: cubit.resetDemoTicket,
          ),
          QrEticketStatus.unconfirmedBooking => _EticketBlockedView(
            icon: Icons.hourglass_bottom_rounded,
            message: state.statusMessage ?? QrEticketState.msg90,
            messageKey: const Key('eticket-unconfirmed-message'),
            isDemoMode: state.isDemoMode,
            onResetDemo: cubit.resetDemoTicket,
          ),
          QrEticketStatus.ready => _EticketReadyView(
            state: state,
            cubit: cubit,
            onBack: () => _handleBack(context),
          ),
        },
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.tourSearch);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Production Pending Integration View (!isDemoMode)
// ─────────────────────────────────────────────────────────────────────────────

class _EticketPendingView extends StatelessWidget {
  const _EticketPendingView({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('eticket-pending-integration-banner'),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hub_outlined,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vé điện tử QR đang chờ tích hợp máy chủ',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Mã QR định danh điểm danh điện tử (UC-29) chỉ được cấp phát từ máy chủ sau khi đơn đặt tour được xác nhận thanh toán (BR-80 / BR-82). Ứng dụng không tự sinh mã QR giả lập trong chế độ Production.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: TourSearchPalette.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Mã tham chiếu đơn: $bookingId',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: TourSearchPalette.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blocked View (Unconfirmed Booking BR-82 / Unauthorized BR-90)
// ─────────────────────────────────────────────────────────────────────────────

class _EticketBlockedView extends StatelessWidget {
  const _EticketBlockedView({
    required this.icon,
    required this.message,
    required this.messageKey,
    required this.isDemoMode,
    required this.onResetDemo,
  });

  final IconData icon;
  final String message;
  final Key messageKey;
  final bool isDemoMode;
  final VoidCallback onResetDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFB45309)),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              key: messageKey,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (kDebugMode && isDemoMode) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                key: const Key('eticket-blocked-reset-demo'),
                onPressed: onResetDemo,
                icon: const Icon(Icons.restore),
                label: const Text('Khôi phục vé hợp lệ (Demo)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error View (MSG127)
// ─────────────────────────────────────────────────────────────────────────────

class _EticketErrorView extends StatelessWidget {
  const _EticketErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              key: const Key('eticket-error-message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('eticket-error-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ready View (UC-29 Screen #69)
// ─────────────────────────────────────────────────────────────────────────────

class _EticketReadyView extends StatelessWidget {
  const _EticketReadyView({
    required this.state,
    required this.cubit,
    required this.onBack,
  });

  final QrEticketState state;
  final QrEticketCubit cubit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final booking = state.booking!;
    final eticket = booking.eticket!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kDebugMode && state.isDemoMode) ...[
            _DemoEticketControlsBar(cubit: cubit),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.statusMessage != null) ...[
            _EticketStatusBanner(
              key: const Key('eticket-status-message-banner'),
              message: state.statusMessage!,
              isWarningOrError: state.isWarningOrError,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _QrPassCard(
            booking: booking,
            eticket: eticket,
            shouldRenderQrCode: state.shouldRenderQrCode,
          ),
          const SizedBox(height: AppSpacing.md),
          _EticketDetailsCard(booking: booking, eticket: eticket),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                key: const Key('eticket-back-button'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
              FilledButton.icon(
                key: const Key('eticket-refresh-qr-button'),
                onPressed: cubit.refreshQrCode,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh QR Code'),
                style: FilledButton.styleFrom(
                  backgroundColor: TourSearchPalette.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _EticketStatusBanner extends StatelessWidget {
  const _EticketStatusBanner({
    required this.message,
    required this.isWarningOrError,
    super.key,
  });

  final String message;
  final bool isWarningOrError;

  @override
  Widget build(BuildContext context) {
    final bgColor = isWarningOrError
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFECFDF5);
    final borderColor = isWarningOrError
        ? const Color(0xFFFDE68A)
        : const Color(0xFFA7F3D0);
    final textColor = isWarningOrError
        ? const Color(0xFFB45309)
        : const Color(0xFF047857);
    final icon = isWarningOrError
        ? Icons.info_outline_rounded
        : Icons.verified_rounded;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPassCard extends StatelessWidget {
  const _QrPassCard({
    required this.booking,
    required this.eticket,
    required this.shouldRenderQrCode,
  });

  final TourBookingRecord booking;
  final QrEticketRecord eticket;
  final bool shouldRenderQrCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (
      badgeLabel,
      badgeIcon,
      badgeColor,
      badgeBg,
    ) = switch (eticket.ticketStatus) {
      TicketLifecycleStatus.valid => (
        'Valid (Sẵn sàng điểm danh)',
        Icons.check_circle_outline,
        const Color(0xFF047857),
        const Color(0xFFECFDF5),
      ),
      TicketLifecycleStatus.notYetActive => (
        'Not Yet Active (Chưa mở cổng)',
        Icons.schedule_outlined,
        const Color(0xFF1D4ED8),
        const Color(0xFFEFF6FF),
      ),
      TicketLifecycleStatus.used => (
        'Used (Đã điểm danh)',
        Icons.task_alt_rounded,
        const Color(0xFF6D28D9),
        const Color(0xFFF5F3FF),
      ),
      TicketLifecycleStatus.cancelled => (
        'Cancelled (Vé đã huỷ)',
        Icons.cancel_outlined,
        const Color(0xFFB91C1C),
        const Color(0xFFFEF2F2),
      ),
      TicketLifecycleStatus.expired => (
        'Expired (Đã qua giờ khởi hành)',
        Icons.timer_off_outlined,
        const Color(0xFF6B7280),
        const Color(0xFFF3F4F6),
      ),
    };

    return Card(
      key: const Key('eticket-qr-card'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Container(
              key: const Key('eticket-ticket-status-badge'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 16, color: badgeColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (shouldRenderQrCode)
              Semantics(
                label: 'Mã QR vé điện tử cho đơn ${booking.bookingId}',
                child: Container(
                  key: const Key('eticket-qr-code-container'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TourSearchPalette.cardBorder),
                  ),
                  child: QrImageView(
                    data: eticket.opaqueQrPayload,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              )
            else
              Container(
                key: const Key('eticket-qr-invalidated-placeholder'),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.qr_code_2_outlined,
                      size: 56,
                      color: Color(0xFFB91C1C),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Mã QR đã vô hiệu hoá (BR-86)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Phiên bản mã: v${eticket.refreshVersion}',
              key: const Key('eticket-qr-version-label'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: TourSearchPalette.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              eticket.validityWindowNote,
              key: const Key('eticket-validity-window-note'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: TourSearchPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EticketDetailsCard extends StatelessWidget {
  const _EticketDetailsCard({required this.booking, required this.eticket});

  final TourBookingRecord booking;
  final QrEticketRecord eticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('eticket-details-card'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin vé điện tử (E-ticket Details)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            _DetailRow(
              label: 'Mã đặt chỗ (Booking Code)',
              value: booking.bookingId,
              valueKey: const Key('eticket-detail-booking-code'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              label: 'Tên tour (Tour Name)',
              value: booking.tourTitle,
              valueKey: const Key('eticket-detail-tour-name'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              label: 'Đơn vị tổ chức (Tour Operator Name)',
              value: booking.operatorName,
              valueKey: const Key('eticket-detail-operator-name'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              label: 'Ngày khởi hành (Departure Date)',
              value: _formatDate(booking.departureAtUtc),
              valueKey: const Key('eticket-detail-departure-date'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              label: 'Điểm tập trung (Meeting Point)',
              value: booking.meetingPoint,
              valueKey: const Key('eticket-detail-meeting-point'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              label: 'Số lượng khách (Number of Participants)',
              value: '${booking.participantCount} khách',
              valueKey: const Key('eticket-detail-participant-count'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              label: 'Trạng thái vé (Ticket Status)',
              value: eticket.ticketStatus.name.toUpperCase(),
              valueKey: const Key('eticket-detail-ticket-status'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: 2,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: TourSearchPalette.muted),
        ),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TourSearchPalette.navy,
          ),
        ),
      ],
    );
  }
}

class _DemoEticketControlsBar extends StatelessWidget {
  const _DemoEticketControlsBar({required this.cubit});

  final QrEticketCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: Color(0xFFB45309)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'UC-29 DEMO SIMULATION CONTROLS (Debug Only)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  key: const Key('demo-uc29-valid'),
                  label: const Text(
                    'Valid (MSG93)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () =>
                      cubit.simulateTicketStatus(TicketLifecycleStatus.valid),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-not-yet-active'),
                  label: const Text(
                    'Not Yet Active (MSG98)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => cubit.simulateTicketStatus(
                    TicketLifecycleStatus.notYetActive,
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-used'),
                  label: const Text(
                    'Used (MSG95)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () =>
                      cubit.simulateTicketStatus(TicketLifecycleStatus.used),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-cancelled'),
                  label: const Text(
                    'Cancelled (MSG74 / BR-86)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => cubit.simulateTicketStatus(
                    TicketLifecycleStatus.cancelled,
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-expired'),
                  label: const Text(
                    'Expired (MSG99)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () =>
                      cubit.simulateTicketStatus(TicketLifecycleStatus.expired),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-unconfirmed'),
                  label: const Text(
                    'Chưa xác nhận (MSG90 / BR-82)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateUnconfirmedBooking,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-non-owner'),
                  label: const Text(
                    'Khác chủ đơn (MSG126 / BR-90)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateNonOwnerAccess,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc29-error'),
                  label: const Text(
                    'Lỗi hệ thống (MSG127)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateSystemError,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dateUtc) {
  final vn = dateUtc.add(const Duration(hours: 7));
  final day = vn.day.toString().padLeft(2, '0');
  final month = vn.month.toString().padLeft(2, '0');
  return '$day/$month/${vn.year}';
}
