import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_cubit.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_state.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Screen #97 Partial Refund Proposal (UC-75).
final class PartialRefundProposalPage extends StatefulWidget {
  const PartialRefundProposalPage({super.key});

  @override
  State<PartialRefundProposalPage> createState() =>
      _PartialRefundProposalPageState();
}

final class _PartialRefundProposalPageState
    extends State<PartialRefundProposalPage> {
  @override
  void initState() {
    super.initState();
    context.read<PartialRefundProposalCubit>().load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<PartialRefundProposalCubit, PartialRefundProposalState>(
    listenWhen: (previous, current) =>
        previous.submitStatus != current.submitStatus &&
        current.submitStatus == PartialRefundSubmitStatus.recorded,
    listener: (context, _) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(PartialRefundProposalStrings.recorded)),
      ),
    builder: (context, state) => Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(PartialRefundProposalStrings.title),
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
      ),
      bottomNavigationBar: _actions(context, state),
      body: switch (state.loadStatus) {
        PartialRefundProposalLoadStatus.initial ||
        PartialRefundProposalLoadStatus.loading => const Center(
          child: LoadingIndicator(),
        ),
        PartialRefundProposalLoadStatus.loaded when state.proposal != null =>
          _Proposal(state: state),
        _ => _Failure(
          message: state.message ?? PartialRefundProposalStrings.systemError,
          onRetry: state.canRetry
              ? context.read<PartialRefundProposalCubit>().load
              : null,
        ),
      },
    ),
  );

  Widget? _actions(BuildContext context, PartialRefundProposalState state) {
    final proposal = state.proposal;
    if (proposal == null || !proposal.canRespond) return null;
    final busy = state.submitStatus == PartialRefundSubmitStatus.submitting;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('partial_refund_decline'),
                    onPressed: busy
                        ? null
                        : () => _confirm(
                            context,
                            PartialRefundDecision.decline,
                            proposal,
                          ),
                    child: const Text(PartialRefundProposalStrings.decline),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const Key('partial_refund_accept'),
                    onPressed: busy
                        ? null
                        : () => _confirm(
                            context,
                            PartialRefundDecision.accept,
                            proposal,
                          ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(PartialRefundProposalStrings.accept),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    PartialRefundDecision decision,
    PartialRefundProposal proposal,
  ) async {
    final accept = decision == PartialRefundDecision.accept;
    final cubit = context.read<PartialRefundProposalCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          accept
              ? PartialRefundProposalStrings.acceptTitle
              : PartialRefundProposalStrings.declineTitle,
        ),
        content: Text(
          accept
              ? PartialRefundProposalStrings.acceptMessage(
                  TripFormatters.formatVnd(proposal.proposedAmount),
                )
              : PartialRefundProposalStrings.declineMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(PartialRefundProposalStrings.cancel),
          ),
          FilledButton(
            key: const Key('partial_refund_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              accept
                  ? PartialRefundProposalStrings.accept
                  : PartialRefundProposalStrings.decline,
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.respond(decision);
  }
}

final class _Proposal extends StatelessWidget {
  const _Proposal({required this.state});
  final PartialRefundProposalState state;

  @override
  Widget build(BuildContext context) {
    final proposal = state.proposal!;
    final presentation = _presentation(proposal.status);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: presentation.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          PartialRefundProposalStrings.bookingLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          proposal.bookingCode,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: presentation.label,
                    type: presentation.badgeType,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                presentation.description,
                style: const TextStyle(color: AppColors.ink, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          elevation: 0,
          color: AppColors.cardBackground,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _Row(
                  PartialRefundProposalStrings.proposedAmount,
                  TripFormatters.formatVnd(proposal.proposedAmount),
                  highlight: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: AppColors.line),
                ),
                _Row(
                  PartialRefundProposalStrings.responseDeadline,
                  TripFormatters.formatVietnamDateTime(
                    proposal.responseDeadlineUtc,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!proposal.canRespond && !state.answeredHere) ...[
          const SizedBox(height: AppSpacing.md),
          const AppAlert(
            type: AppAlertType.info,
            message: PartialRefundProposalStrings.responseClosed,
          ),
        ],
        if (state.submitStatus == PartialRefundSubmitStatus.failed &&
            state.message != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlert(type: AppAlertType.error, message: state.message!),
        ],
      ],
    );
  }
}

final class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: highlight ? 15 : 13.5,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.ink,
          ),
        ),
      ),
    ],
  );
}

final class _Failure extends StatelessWidget {
  const _Failure({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAlert(message: message, type: AppAlertType.error),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(PartialRefundProposalStrings.retry),
            ),
          ],
        ],
      ),
    ),
  );
}

({
  String label,
  String description,
  StatusBadgeType badgeType,
  Color background,
})
_presentation(PartialRefundProposalStatus status) => switch (status) {
  PartialRefundProposalStatus.awaitingTravelerResponse => (
    label: PartialRefundProposalStrings.statusAwaitingTraveler,
    description: PartialRefundProposalStrings.descriptionAwaitingTraveler,
    badgeType: StatusBadgeType.warning,
    background: const Color(0xFFFEF6E6),
  ),
  PartialRefundProposalStatus.approved => (
    label: PartialRefundProposalStrings.statusApproved,
    description: PartialRefundProposalStrings.descriptionApproved,
    badgeType: StatusBadgeType.success,
    background: const Color(0xFFE7F6F0),
  ),
  PartialRefundProposalStatus.declined => (
    label: PartialRefundProposalStrings.statusDeclined,
    description: PartialRefundProposalStrings.descriptionDeclined,
    badgeType: StatusBadgeType.neutral,
    background: const Color(0xFFEFECE4),
  ),
  PartialRefundProposalStatus.awaitingOperatorResponse => (
    label: PartialRefundProposalStrings.statusAwaitingOperator,
    description: PartialRefundProposalStrings.descriptionAwaitingOperator,
    badgeType: StatusBadgeType.info,
    background: AppColors.primarySoft,
  ),
  PartialRefundProposalStatus.rejected => (
    label: PartialRefundProposalStrings.statusRejected,
    description: PartialRefundProposalStrings.descriptionRejected,
    badgeType: StatusBadgeType.neutral,
    background: const Color(0xFFEFECE4),
  ),
  PartialRefundProposalStatus.expired => (
    label: PartialRefundProposalStrings.statusExpired,
    description: PartialRefundProposalStrings.descriptionExpired,
    badgeType: StatusBadgeType.neutral,
    background: const Color(0xFFEFECE4),
  ),
};
