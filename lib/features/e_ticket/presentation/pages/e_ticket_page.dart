import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/widgets/booking_cancel_sheet.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_cubit.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_state.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/widgets/e_ticket_qr_code.dart';
import 'package:trip_mate_mobile/features/e_ticket/resources/e_ticket_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

/// UC-29 View QR E-ticket. The QR shown is exactly the server's `qr.content`.
class ETicketPage extends StatelessWidget {
  const ETicketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(ETicketStrings.title),
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
        leading: IconButton(
          tooltip: ETicketStrings.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.tripHistory);
            }
          },
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<ETicketCubit, ETicketState>(
          builder: (context, state) => switch (state.phase) {
            ETicketPhase.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            ETicketPhase.failure => _FailureView(
              kind: state.failure ?? ETicketFailureKind.system,
            ),
            ETicketPhase.ready => _TicketView(state: state),
          },
        ),
      ),
    );
  }
}

final class _FailureView extends StatelessWidget {
  const _FailureView({required this.kind});

  final ETicketFailureKind kind;

  String get _message => switch (kind) {
    ETicketFailureKind.signIn => ETicketStrings.signIn,
    ETicketFailureKind.forbidden => ETicketStrings.msg126,
    ETicketFailureKind.notFound => ETicketStrings.notFound,
    ETicketFailureKind.notConfirmed => ETicketStrings.msg138,
    ETicketFailureKind.notIssued ||
    ETicketFailureKind.notRefreshable ||
    ETicketFailureKind.system => ETicketStrings.msg127,
  };

  bool get _canRetry =>
      kind == ETicketFailureKind.system || kind == ETicketFailureKind.notIssued;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(_message, textAlign: TextAlign.center),
            if (_canRetry) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.read<ETicketCubit>().load(),
                child: const Text(ETicketStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _TicketView extends StatelessWidget {
  const _TicketView({required this.state});

  final ETicketState state;

  @override
  Widget build(BuildContext context) {
    final ticket = state.ticket!;
    final departureDate = _calendarDate(ticket.departureDate);
    final qr = ticket.qr;
    final isActive = ticket.status.showsQr;
    final statusVisual = _statusVisual(ticket.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.staleQr) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEEEF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ETicketStrings.msg127,
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    ETicketStrings.staleQr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Coastal Boarding-Pass Ticket Card
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Boarding-Pass Header Band
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  color: isActive ? AppColors.primary : const Color(0xFFEFECE4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: statusVisual.pillBg,
                            side: BorderSide.none,
                            label: Text(
                              ETicketStrings.statusLabel(ticket.status),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: statusVisual.pillFg,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.72)
                                : AppColors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ticket.tourTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isActive ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 17.5,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ticket.operatorName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.84)
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status message notice bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: statusVisual.noticeBg,
                  child: Text(
                    _statusMessage(ticket, departureDate),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: statusVisual.noticeFg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // QR Presentation Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    children: [
                      if (qr != null) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final size = (constraints.maxWidth - 24).clamp(
                              168.0,
                              220.0,
                            );
                            return Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: ETicketQrCode(
                                  content: qr.content,
                                  size: size,
                                  semanticsLabel:
                                      'Mã QR của vé ${ticket.ticketCode}',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          ticket.ticketCode,
                          style: const TextStyle(
                            fontFamily: AppTypography.uiFont,
                            fontFeatures: [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            letterSpacing: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ETicketStrings.validityNote(departureDate),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Boarding-pass tear line with side notches
                const _TicketPerforation(),
                // Booking Metadata Stub
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      _InfoRow(ETicketStrings.ticketCode, ticket.ticketCode),
                      const Divider(height: 1, color: AppColors.line),
                      _InfoRow(ETicketStrings.bookingCode, ticket.bookingCode),
                      const Divider(height: 1, color: AppColors.line),
                      _InfoRow(
                        ETicketStrings.departure,
                        TripFormatters.formatVietnamDateTime(ticket.startAtUtc),
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _InfoRow(
                        ETicketStrings.meetingPoint,
                        ticket.meetingPoint ??
                            ETicketStrings.meetingPointMissing,
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _InfoRow(
                        ETicketStrings.participants,
                        ETicketStrings.participantSummary(
                          ticket.adults,
                          ticket.children,
                          ticket.infants,
                          ticket.participantCount,
                        ),
                      ),
                      if (ticket.checkedInAtUtc case final checkedIn?) ...[
                        const Divider(height: 1, color: AppColors.line),
                        _InfoRow(
                          ETicketStrings.checkedInAt,
                          TripFormatters.formatVietnamDateTime(checkedIn),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: state.canRefresh
                    ? () => _confirmRefresh(context)
                    : null,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  state.refreshing
                      ? ETicketStrings.refreshing
                      : ETicketStrings.refresh,
                ),
              ),
            ),
            if (!state.online) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text(
                ETicketStrings.offline,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: () => _cancelBooking(context, ticket.bookingId),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFDEEEF),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.28),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Hủy đặt tour'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static ({Color pillBg, Color pillFg, Color noticeBg, Color noticeFg})
  _statusVisual(ETicketStatus status) => switch (status) {
    ETicketStatus.valid => (
      pillBg: const Color(0xFFE7F6F0),
      pillFg: const Color(0xFF0A6C4B),
      noticeBg: AppColors.primarySoft,
      noticeFg: AppColors.primary,
    ),
    ETicketStatus.notYetActive => (
      pillBg: const Color(0xFFFEF6E6),
      pillFg: AppColors.warning,
      noticeBg: const Color(0xFFFEF6E6),
      noticeFg: AppColors.warning,
    ),
    ETicketStatus.used => (
      pillBg: AppColors.cardBackground,
      pillFg: AppColors.muted,
      noticeBg: const Color(0xFFF5F3EC),
      noticeFg: AppColors.ink,
    ),
    ETicketStatus.cancelled => (
      pillBg: const Color(0xFFFDEEEF),
      pillFg: AppColors.error,
      noticeBg: const Color(0xFFFDEEEF),
      noticeFg: AppColors.error,
    ),
    ETicketStatus.expired => (
      pillBg: AppColors.cardBackground,
      pillFg: AppColors.muted,
      noticeBg: const Color(0xFFF5F3EC),
      noticeFg: AppColors.muted,
    ),
  };

  /// `dd/MM/yyyy` of a calendar date (the departure date is already a Vietnam date).
  static String _calendarDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _statusMessage(ETicket ticket, String departureDate) =>
      switch (ticket.status) {
        ETicketStatus.valid => ETicketStrings.msg93,
        ETicketStatus.notYetActive => ETicketStrings.msg98(departureDate),
        ETicketStatus.used => ETicketStrings.msg95(
          ticket.checkedInAtUtc == null
              ? ''
              : TripFormatters.formatVietnamDateTime(ticket.checkedInAtUtc!),
        ),
        ETicketStatus.cancelled => ETicketStrings.msg139(ticket.bookingCode),
        ETicketStatus.expired => ETicketStrings.msg140(departureDate),
      };

  Future<void> _confirmRefresh(BuildContext context) async {
    final cubit = context.read<ETicketCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(ETicketStrings.refreshConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(ETicketStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(ETicketStrings.confirmRefresh),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.refresh();
  }

  Future<void> _cancelBooking(BuildContext context, int bookingId) async {
    final cubit = context.read<ETicketCubit>();
    final cancelled = await BookingCancelSheet.show(
      context,
      bookingId: bookingId,
    );
    if (cancelled == true) await cubit.load();
  }
}

final class _TicketPerforation extends StatelessWidget {
  const _TicketPerforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final count = (constraints.maxWidth / 10).floor().clamp(8, 48);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => const SizedBox(
                      width: 5,
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: AppColors.line),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const Positioned(
            left: -10,
            child: SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            right: -10,
            child: SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
