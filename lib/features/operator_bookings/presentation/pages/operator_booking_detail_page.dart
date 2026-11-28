import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_bookings/utils/operator_booking_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Booking details and passenger manifest (UC-40, screen #85). Read-only: it carries no cancel, refund or
/// check-in control (UC-41, UC-42 and UC-43 are separate). It needs an [OperatorBookingDetailCubit] above it.
class OperatorBookingDetailPage extends StatelessWidget {
  const OperatorBookingDetailPage({this.initialBooking, super.key});

  /// The list card this page was opened from: its basics show at once, before the detail arrives.
  final OperatorBookingListItem? initialBooking;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(
        title: OperatorBookingsStringsEn.detailTitle,
      ),
      body: BlocBuilder<OperatorBookingDetailCubit, OperatorBookingDetailState>(
        builder: (context, state) {
          final detail = state.detail;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detail != null)
                  _Header.fromDetail(detail)
                else if (initialBooking != null)
                  _Header.fromListItem(initialBooking!),
                if (detail != null) ..._sections(detail),
                if (state.status == OperatorBookingDetailStatus.loading)
                  const _LoadingPlaceholder(),
                if (state.status == OperatorBookingDetailStatus.failure)
                  _FailureBody(
                    message:
                        state.errorMessage ??
                        OperatorBookingsStringsEn.systemError,
                    onRetry: state.canRetry
                        ? context.read<OperatorBookingDetailCubit>().retry
                        : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(OperatorBookingDetail detail) {
    final schedule = detail.schedule;
    final booker = detail.booker;
    final ticket = detail.ticket;
    final payment = detail.payment;
    final coupon = detail.coupon;
    final hasCancellation =
        detail.cancelledAtUtc != null || detail.cancelReason != null;
    return [
      _Section(
        icon: Icons.tour_outlined,
        title: OperatorBookingsStringsEn.detailTour,
        children: [
          _Line(
            OperatorBookingsStringsEn.detailDeparture,
            OperatorBookingFormatters.dateTime(schedule.startAtUtc),
          ),
          if (schedule.meetingPoint != null)
            _Line(
              OperatorBookingsStringsEn.detailMeetingPoint,
              schedule.meetingPoint!,
            ),
          _Line(
            OperatorBookingsStringsEn.detailCheckIn,
            OperatorBookingFormatters.checkInLabel(detail.checkInStatus),
          ),
          if (detail.checkedInAtUtc != null)
            _Line(
              OperatorBookingsStringsEn.detailCheckedInAt,
              OperatorBookingFormatters.dateTime(detail.checkedInAtUtc!),
            ),
          _Line(
            OperatorBookingsStringsEn.detailBookedAt,
            OperatorBookingFormatters.dateTime(detail.bookedAtUtc),
          ),
        ],
      ),
      _Section(
        icon: Icons.person_outline,
        title: OperatorBookingsStringsEn.detailBooker,
        children: [
          _Line(OperatorBookingsStringsEn.cardBooker, booker.fullName),
          _Line(
            OperatorBookingsStringsEn.detailPhone,
            booker.phoneNumber ?? OperatorBookingsStringsEn.notAvailable,
          ),
          _Line(
            OperatorBookingsStringsEn.detailEmail,
            booker.email ?? OperatorBookingsStringsEn.notAvailable,
          ),
        ],
      ),
      _Section(
        icon: Icons.groups_outlined,
        title: OperatorBookingsStringsEn.detailManifest,
        trailing: '(${detail.participants.length})',
        children: [
          for (var i = 0; i < detail.participants.length; i++)
            _ParticipantRow(index: i + 1, participant: detail.participants[i]),
        ],
      ),
      if (ticket != null)
        _Section(
          icon: Icons.confirmation_number_outlined,
          title: OperatorBookingsStringsEn.detailTicket,
          children: [
            _Line(
              OperatorBookingsStringsEn.detailTicketCode,
              ticket.ticketCode,
            ),
            _Line(
              OperatorBookingsStringsEn.detailTicketStatus,
              OperatorBookingFormatters.ticketStatusLabel(ticket.status),
            ),
          ],
        ),
      if (payment != null)
        _Section(
          icon: Icons.payment_outlined,
          title: OperatorBookingsStringsEn.detailPayment,
          children: [
            _Line(
              OperatorBookingsStringsEn.detailGateway,
              OperatorBookingFormatters.gatewayLabel(payment.gateway),
            ),
            _Line(
              OperatorBookingsStringsEn.detailReference,
              payment.gatewayTransactionRef ??
                  OperatorBookingsStringsEn.notAvailable,
            ),
            _Line(
              OperatorBookingsStringsEn.detailAmount,
              OperatorBookingFormatters.formatVnd(payment.amount),
            ),
            if (payment.succeededAtUtc != null)
              _Line(
                OperatorBookingsStringsEn.detailPaidAt,
                OperatorBookingFormatters.dateTime(payment.succeededAtUtc!),
              ),
          ],
        ),
      _Section(
        icon: Icons.receipt_long_outlined,
        title: OperatorBookingsStringsEn.detailPricing,
        children: [
          _Line(
            OperatorBookingsStringsEn.detailPaymentStatus,
            OperatorBookingFormatters.paymentStatusLabel(detail.paymentStatus),
          ),
          _Line(
            OperatorBookingsStringsEn.detailSubtotal,
            OperatorBookingFormatters.formatVnd(detail.subtotalAmount),
          ),
          if (coupon != null)
            _Line(
              OperatorBookingsStringsEn.detailCoupon,
              '${coupon.code} - ${coupon.name}',
            ),
          if (detail.discountAmount > 0)
            _Line(
              OperatorBookingsStringsEn.detailDiscount,
              OperatorBookingFormatters.formatVnd(detail.discountAmount),
            ),
          _Line(
            OperatorBookingsStringsEn.detailTotal,
            OperatorBookingFormatters.formatVnd(detail.totalAmount),
            emphasised: true,
          ),
          _Line(
            OperatorBookingsStringsEn.detailPaidAmount,
            OperatorBookingFormatters.formatVnd(detail.paidAmount),
          ),
        ],
      ),
      if (hasCancellation)
        _Section(
          icon: Icons.cancel_outlined,
          title: OperatorBookingsStringsEn.detailCancellation,
          children: [
            if (detail.cancelledAtUtc != null)
              _Line(
                OperatorBookingsStringsEn.detailCancelledAt,
                OperatorBookingFormatters.dateTime(detail.cancelledAtUtc!),
              ),
            if (detail.cancelReason != null)
              _Line(
                OperatorBookingsStringsEn.detailCancelReason,
                detail.cancelReason!,
              ),
          ],
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.code,
    required this.status,
    required this.tourTitle,
    required this.departure,
    required this.checkInStatus,
  });

  factory _Header.fromDetail(OperatorBookingDetail detail) => _Header(
    code: detail.bookingCode,
    status: detail.status,
    tourTitle: detail.tour.title,
    departure: detail.schedule.startAtUtc,
    checkInStatus: detail.checkInStatus,
  );

  factory _Header.fromListItem(OperatorBookingListItem item) => _Header(
    code: item.bookingCode,
    status: item.status,
    tourTitle: item.tour.title,
    departure: item.schedule.startAtUtc,
    checkInStatus: item.checkInStatus,
  );

  final String code;
  final OperatorBookingStatus status;
  final String tourTitle;
  final DateTime departure;
  final OperatorCheckInStatus checkInStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  code,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                StatusBadge(
                  label: OperatorBookingFormatters.statusLabel(status),
                  type: OperatorBookingFormatters.statusBadge(status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              tourTitle,
              style: textTheme.bodyMedium?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${OperatorBookingsStringsEn.cardDeparture}: '
              '${OperatorBookingFormatters.date(departure)}',
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            StatusBadge(
              label: OperatorBookingFormatters.checkInLabel(checkInStatus),
              type: OperatorBookingFormatters.checkInBadge(checkInStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSectionCard(
        title: title,
        icon: icon,
        trailing: trailing != null
            ? Text(
                trailing!,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.textMuted,
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.emphasised = false});

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: style?.copyWith(color: c.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: style?.copyWith(
                color: emphasised ? c.brandTeal : c.textPrimary,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.index, required this.participant});

  final int index;
  final OperatorBookingParticipant participant;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              '$index.',
              style: style?.copyWith(
                color: c.brandTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              participant.fullName,
              style: style?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 2,
            child: Text(
              OperatorBookingFormatters.participantTypeLabel(participant.type),
              textAlign: TextAlign.end,
              style: style?.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Column(
      key: const Key('operator-booking-detail-loading'),
      children: [
        for (final height in const [96.0, 120.0, 88.0])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppShimmer(
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: c.shimmerBase,
                  borderRadius: BorderRadius.circular(TripMateRadius.lg),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 30, color: c.error),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: OperatorBookingsStringsEn.retry,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
