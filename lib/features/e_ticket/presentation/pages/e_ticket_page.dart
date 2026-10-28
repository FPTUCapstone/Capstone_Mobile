import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
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
      appBar: AppBar(title: const Text(ETicketStrings.title)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(ETicketStrings.statusLabel(ticket.status))),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_statusMessage(ticket, departureDate)),
          if (state.staleQr) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ETicketStrings.msg127),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      ETicketStrings.staleQr,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(ticket.tourTitle, style: Theme.of(context).textTheme.titleLarge),
          Text(ticket.operatorName),
          const SizedBox(height: AppSpacing.md),
          if (qr != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxWidth.clamp(200.0, 280.0);
                return Center(
                  child: ETicketQrCode(
                    content: qr.content,
                    size: size,
                    semanticsLabel: 'QR code of ticket ${ticket.ticketCode}',
                  ),
                );
              },
            ),
          Center(
            child: Text(
              ticket.ticketCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(child: Text(ETicketStrings.validityNote(departureDate))),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(ETicketStrings.ticketCode, ticket.ticketCode),
          _InfoRow(ETicketStrings.bookingCode, ticket.bookingCode),
          _InfoRow(
            ETicketStrings.departure,
            TripFormatters.formatVietnamDateTime(ticket.startAtUtc),
          ),
          _InfoRow(
            ETicketStrings.meetingPoint,
            ticket.meetingPoint ?? ETicketStrings.meetingPointMissing,
          ),
          _InfoRow(
            ETicketStrings.participants,
            ETicketStrings.participantSummary(
              ticket.adults,
              ticket.children,
              ticket.infants,
              ticket.participantCount,
            ),
          ),
          if (ticket.checkedInAtUtc case final checkedIn?)
            _InfoRow(
              ETicketStrings.checkedInAt,
              TripFormatters.formatVietnamDateTime(checkedIn),
            ),
          if (ticket.status.showsQr) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: state.canRefresh
                  ? () => _confirmRefresh(context)
                  : null,
              icon: const Icon(Icons.refresh),
              label: Text(
                state.refreshing
                    ? ETicketStrings.refreshing
                    : ETicketStrings.refresh,
              ),
            ),
            if (!state.online) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(ETicketStrings.offline, textAlign: TextAlign.center),
            ],
          ],
        ],
      ),
    );
  }

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
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
