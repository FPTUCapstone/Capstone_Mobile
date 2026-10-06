import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_cubit.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_state.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

/// Screen #67 — Electronic Payment Page (UC-28 Make Electronic Payment).
class ElectronicPaymentPage extends StatelessWidget {
  const ElectronicPaymentPage({
    required this.bookingId,
    this.initialBooking,
    this.isDemoMode = false,
    this.enableTicker = true,
    super.key,
  });

  final String bookingId;
  final TourBookingRecord? initialBooking;
  final bool isDemoMode;
  final bool enableTicker;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ElectronicPaymentCubit(
        bookingId: bookingId,
        initialBooking: initialBooking,
        isDemoMode: isDemoMode,
        enableTicker: enableTicker,
      )..load(),
      child: _ElectronicPaymentView(bookingId: bookingId),
    );
  }
}

class _ElectronicPaymentView extends StatelessWidget {
  const _ElectronicPaymentView({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ElectronicPaymentCubit>();
    final state = cubit.state;

    return Scaffold(
      backgroundColor: TourSearchPalette.background,
      appBar: AppBar(
        title: const Text('Thanh toán điện tử'),
        backgroundColor: Colors.white,
        foregroundColor: TourSearchPalette.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Trở về',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.tourSearch);
            }
          },
        ),
      ),
      body: SafeArea(
        child: switch (state.status) {
          ElectronicPaymentStatus.initial ||
          ElectronicPaymentStatus.loading => const Center(
            child: CircularProgressIndicator(color: TourSearchPalette.teal),
          ),
          ElectronicPaymentStatus.error => _PaymentErrorView(
            message: state.errorMessage ?? ElectronicPaymentState.msg127,
            onRetry: cubit.load,
          ),
          ElectronicPaymentStatus.pendingIntegration => _PaymentPendingView(
            bookingId: bookingId,
          ),
          ElectronicPaymentStatus.unauthorized => _PaymentUnauthorizedView(
            message: state.noticeMessage ?? ElectronicPaymentState.msg126,
            isDemoMode: state.isDemoMode,
            onResetDemo: cubit.resetDemoPaymentState,
          ),
          ElectronicPaymentStatus.ready => _PaymentReadyView(
            state: state,
            cubit: cubit,
          ),
        },
      ),
      bottomNavigationBar: state.status == ElectronicPaymentStatus.ready
          ? _PaymentBottomBar(state: state, cubit: cubit)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Production Pending Integration View (!isDemoMode)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentPendingView extends StatelessWidget {
  const _PaymentPendingView({required this.bookingId});

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
            key: const Key('payment-pending-integration-banner'),
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
                        'Cổng thanh toán điện tử đang chờ tích hợp máy chủ',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Chức năng khởi tạo giao dịch VNPay / PayOS và xác thực kết quả thanh toán qua IPN từ máy chủ (UC-28) sẽ khả dụng sau khi dịch vụ Payment Backend hoàn tất tích hợp.',
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
// Unauthorized View (BR-90 / MSG126)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentUnauthorizedView extends StatelessWidget {
  const _PaymentUnauthorizedView({
    required this.message,
    required this.isDemoMode,
    required this.onResetDemo,
  });

  final String message;
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
            const Icon(Icons.lock_outline, size: 56, color: Color(0xFFDC2626)),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              key: const Key('payment-unauthorized-message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (kDebugMode && isDemoMode) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                key: const Key('payment-unauthorized-reset-demo'),
                onPressed: onResetDemo,
                icon: const Icon(Icons.restore),
                label: const Text('Khôi phục quyền chủ đơn (Demo)'),
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

class _PaymentErrorView extends StatelessWidget {
  const _PaymentErrorView({required this.message, required this.onRetry});

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
              key: const Key('payment-error-message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('payment-error-retry-button'),
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
// Ready View (UC-28)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentReadyView extends StatelessWidget {
  const _PaymentReadyView({required this.state, required this.cubit});

  final ElectronicPaymentState state;
  final ElectronicPaymentCubit cubit;

  @override
  Widget build(BuildContext context) {
    final booking = state.booking!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kDebugMode && state.isDemoMode) ...[
            _DemoPaymentControlsBar(cubit: cubit),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.noticeMessage != null) ...[
            _PaymentNoticeBanner(
              key: const Key('payment-notice-banner'),
              message: state.noticeMessage!,
              isError: state.isErrorNotice,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _CountdownAndStatusCard(state: state, booking: booking),
          const SizedBox(height: AppSpacing.md),
          _PaymentBookingSummaryCard(booking: booking),
          const SizedBox(height: AppSpacing.md),
          _PaymentMethodSelectorCard(state: state, cubit: cubit),
          if (booking.latestTransaction != null) ...[
            const SizedBox(height: AppSpacing.md),
            _TransactionStatusCard(transaction: booking.latestTransaction!),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _PaymentNoticeBanner extends StatelessWidget {
  const _PaymentNoticeBanner({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bgColor = isError ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);
    final borderColor = isError
        ? const Color(0xFFFECACA)
        : const Color(0xFFBFDBFE);
    final textColor = isError
        ? const Color(0xFFB91C1C)
        : const Color(0xFF1D4ED8);
    final icon = isError ? Icons.error_outline : Icons.info_outline;

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

class _CountdownAndStatusCard extends StatelessWidget {
  const _CountdownAndStatusCard({required this.state, required this.booking});

  final ElectronicPaymentState state;
  final TourBookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (
      statusLabel,
      statusIcon,
      statusColor,
      statusBg,
    ) = switch (booking.status) {
      BookingLifecycleStatus.pendingPayment => (
        'Pending Payment (Chờ thanh toán)',
        Icons.hourglass_top_rounded,
        const Color(0xFFB45309),
        const Color(0xFFFEF3C7),
      ),
      BookingLifecycleStatus.confirmed => (
        'Confirmed (Đã xác nhận)',
        Icons.verified_rounded,
        const Color(0xFF047857),
        const Color(0xFFECFDF5),
      ),
      BookingLifecycleStatus.cancelled => (
        'Cancelled (Đã huỷ)',
        Icons.cancel_outlined,
        const Color(0xFFB91C1C),
        const Color(0xFFFEF2F2),
      ),
      BookingLifecycleStatus.expired => (
        'Expired (Hết hạn thanh toán)',
        Icons.timer_off_outlined,
        const Color(0xFF6B7280),
        const Color(0xFFF3F4F6),
      ),
    };

    final minutes = state.remainingPaymentDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = state.remainingPaymentDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Card(
      key: const Key('payment-status-card'),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  'Trạng thái đơn đặt tour',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: TourSearchPalette.muted,
                  ),
                ),
                Container(
                  key: const Key('payment-booking-status-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 15, color: statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: 4,
              children: [
                const Text(
                  'Thời gian thanh toán còn lại (Remaining Time):',
                  style: TextStyle(
                    fontSize: 13,
                    color: TourSearchPalette.muted,
                  ),
                ),
                Text(
                  '$minutes:$seconds',
                  key: const Key('payment-countdown-value'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: state.remainingPaymentDuration <= Duration.zero
                        ? const Color(0xFFDC2626)
                        : TourSearchPalette.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBookingSummaryCard extends StatelessWidget {
  const _PaymentBookingSummaryCard({required this.booking});

  final TourBookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('payment-booking-summary-card'),
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
              'Thông tin đơn đặt tour (Booking Summary)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            _SummaryRow(
              label: 'Mã đặt chỗ (Booking Code)',
              value: booking.bookingId,
              valueKey: const Key('payment-summary-booking-code'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Tên tour (Tour Name)',
              value: booking.tourTitle,
              valueKey: const Key('payment-summary-tour-name'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Ngày khởi hành (Departure Date)',
              value: _formatDate(booking.departureAtUtc),
              valueKey: const Key('payment-summary-departure-date'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Số lượng khách (Participant Count)',
              value: '${booking.participantCount} khách',
              valueKey: const Key('payment-summary-participant-count'),
            ),
            const Divider(height: AppSpacing.lg),
            _SummaryRow(
              label: 'Tổng thanh toán (Total Amount - VND)',
              value: _formatVnd(booking.totalAmount),
              valueKey: const Key('payment-summary-total-amount'),
              highlightTeal: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.highlightTeal = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool highlightTeal;

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
          style: TextStyle(
            fontSize: highlightTeal ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: highlightTeal
                ? TourSearchPalette.teal
                : TourSearchPalette.navy,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodSelectorCard extends StatelessWidget {
  const _PaymentMethodSelectorCard({required this.state, required this.cubit});

  final ElectronicPaymentState state;
  final ElectronicPaymentCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = state.canProceedToPayment;

    return Card(
      key: const Key('payment-method-card'),
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
              'Phương thức thanh toán (Payment Method)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _GatewayOptionTile(
              key: const Key('payment-method-vnpay'),
              method: PaymentGatewayMethod.vnpay,
              title: 'VNPay',
              subtitle: 'Thanh toán qua cổng VNPay QR / Thẻ ATM nội địa',
              selected: state.selectedMethod == PaymentGatewayMethod.vnpay,
              enabled: isInteractive,
              onTap: () =>
                  cubit.selectPaymentMethod(PaymentGatewayMethod.vnpay),
            ),
            const SizedBox(height: AppSpacing.xs),
            _GatewayOptionTile(
              key: const Key('payment-method-payos'),
              method: PaymentGatewayMethod.payos,
              title: 'PayOS',
              subtitle: 'Chuyển khoản nhanh VietQR qua cổng PayOS',
              selected: state.selectedMethod == PaymentGatewayMethod.payos,
              enabled: isInteractive,
              onTap: () =>
                  cubit.selectPaymentMethod(PaymentGatewayMethod.payos),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayOptionTile extends StatelessWidget {
  const _GatewayOptionTile({
    required this.method,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final PaymentGatewayMethod method;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? TourSearchPalette.teal
        : TourSearchPalette.cardBorder;
    final bgColor = selected ? const Color(0xFFF0FDFA) : Colors.white;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? TourSearchPalette.teal
                  : TourSearchPalette.muted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TourSearchPalette.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TourSearchPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionStatusCard extends StatelessWidget {
  const _TransactionStatusCard({required this.transaction});

  final PaymentTransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verificationLabel = switch (transaction.status) {
      PaymentVerificationStatus.notStarted => 'Chưa khởi tạo',
      PaymentVerificationStatus.redirectingToGateway =>
        'Đang chuyển hướng cổng thanh toán (Redirecting)',
      PaymentVerificationStatus.pendingVerification =>
        'Chờ xác thực IPN từ máy chủ (Pending Server Verification)',
      PaymentVerificationStatus.verifiedSuccess =>
        'Máy chủ đã xác thực thành công (Verified Success)',
      PaymentVerificationStatus.failedOrCancelled =>
        'Giao dịch thất bại / Đã huỷ tại cổng (Failed / Cancelled)',
      PaymentVerificationStatus.timeout =>
        'Hết thời gian kết nối cổng (Timeout)',
      PaymentVerificationStatus.reconciliationRequired =>
        'Cần đối soát thủ công (Reconciliation Required)',
    };

    return Card(
      key: const Key('payment-transaction-card'),
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
              'Giao dịch thanh toán (BR-71 / BR-73)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Mã giao dịch',
              value: transaction.transactionId,
              valueKey: const Key('payment-transaction-id'),
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              label: 'Cổng thanh toán',
              value: transaction.method == PaymentGatewayMethod.vnpay
                  ? 'VNPay'
                  : 'PayOS',
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              label: 'Trạng thái xác thực',
              value: verificationLabel,
              valueKey: const Key('payment-transaction-status'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBottomBar extends StatelessWidget {
  const _PaymentBottomBar({required this.state, required this.cubit});

  final ElectronicPaymentState state;
  final ElectronicPaymentCubit cubit;

  @override
  Widget build(BuildContext context) {
    final booking = state.booking;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TourSearchPalette.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton(
              key: const Key('payment-cancel-booking-button'),
              onPressed: state.canCancelBooking
                  ? () => _confirmCancelBooking(context, cubit)
                  : null,
              child: const Text('Cancel Booking'),
            ),
            if (state.isConfirmed && booking != null)
              FilledButton.icon(
                key: const Key('payment-view-eticket-button'),
                onPressed: () {
                  context.push(
                    AppRoutes.bookingEticket(
                      booking.bookingId,
                      demo: state.isDemoMode,
                    ),
                    extra: booking,
                  );
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('View QR E-ticket'),
                style: FilledButton.styleFrom(
                  backgroundColor: TourSearchPalette.teal,
                ),
              )
            else
              FilledButton(
                key: const Key('payment-proceed-button'),
                onPressed: state.canProceedToPayment
                    ? cubit.proceedToPayment
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: TourSearchPalette.teal,
                ),
                child: const Text('Proceed to Payment'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelBooking(
    BuildContext context,
    ElectronicPaymentCubit cubit,
  ) async {
    // CR-05 confirmation dialog before cancelling booking.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ đơn đặt tour'),
        content: const Text(
          'Bạn có chắc chắn muốn huỷ đơn đặt tour này? Số chỗ đang giữ tạm thời sẽ được hoàn trả lại cho lịch trình.',
        ),
        actions: [
          TextButton(
            key: const Key('payment-cancel-dialog-dismiss'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            key: const Key('payment-cancel-dialog-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      cubit.cancelBooking();
    }
  }
}

class _DemoPaymentControlsBar extends StatelessWidget {
  const _DemoPaymentControlsBar({required this.cubit});

  final ElectronicPaymentCubit cubit;

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
                  'UC-28 DEMO SIMULATION CONTROLS (Debug Only)',
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
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                key: const Key('demo-uc28-reset'),
                label: const Text(
                  'Reset Pending',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.resetDemoPaymentState,
              ),
              ActionChip(
                key: const Key('demo-uc28-gateway-return'),
                label: const Text(
                  'Redirect về App (MSG90 - Chưa xác nhận)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateGatewayReturnNonAuthoritative,
              ),
              ActionChip(
                key: const Key('demo-uc28-verified-success'),
                label: const Text(
                  'IPN Thành công (MSG86 - Confirmed)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateVerifiedServerPayment,
              ),
              ActionChip(
                key: const Key('demo-uc28-gateway-fail'),
                label: const Text(
                  'Thất bại / Huỷ cổng (MSG87)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateGatewayFailedOrCancelled,
              ),
              ActionChip(
                key: const Key('demo-uc28-gateway-timeout'),
                label: const Text(
                  'Lỗi kết nối cổng (MSG89)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateGatewayTimeout,
              ),
              ActionChip(
                key: const Key('demo-uc28-reconciliation'),
                label: const Text(
                  'Lệch đối soát (MSG92)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateReconciliationMismatch,
              ),
              ActionChip(
                key: const Key('demo-uc28-duplicate-ipn'),
                label: const Text(
                  'Trùng / Sai IPN (MSG91)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateDuplicateOrUnmatchedNotification,
              ),
              ActionChip(
                key: const Key('demo-uc28-expired'),
                label: const Text(
                  'Hết hạn 15p (MSG80)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulatePaymentWindowExpired,
              ),
              ActionChip(
                key: const Key('demo-uc28-already-paid'),
                label: const Text(
                  'Đã thanh toán (MSG88)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateAlreadyPaid,
              ),
              ActionChip(
                key: const Key('demo-uc28-non-owner'),
                label: const Text(
                  'Khác chủ đơn (MSG126)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateNonOwnerAccess,
              ),
              ActionChip(
                key: const Key('demo-uc28-error'),
                label: const Text(
                  'Lỗi hệ thống (MSG127)',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: cubit.simulateSystemError,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatVnd(int price) {
  final text = price.toString();
  final buffer = StringBuffer();
  final length = text.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  buffer.write('₫');
  return buffer.toString();
}

String _formatDate(DateTime dateUtc) {
  final vn = dateUtc.add(const Duration(hours: 7));
  final day = vn.day.toString().padLeft(2, '0');
  final month = vn.month.toString().padLeft(2, '0');
  return '$day/$month/${vn.year}';
}
