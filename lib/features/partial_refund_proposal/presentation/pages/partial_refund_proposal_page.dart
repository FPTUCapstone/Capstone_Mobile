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
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sticky_action_bar.dart';
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
    builder: (context, state) {
      final c = context.tmColors;
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(
          title: PartialRefundProposalStrings.title,
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
      );
    },
  );

  Widget? _actions(BuildContext context, PartialRefundProposalState state) {
    final proposal = state.proposal;
    if (proposal == null || !proposal.canRespond) return null;
    final c = context.tmColors;
    final busy = state.submitStatus == PartialRefundSubmitStatus.submitting;
    return AppStickyActionBar(
      secondaryAction: SizedBox(
        height: 46,
        child: OutlinedButton(
          key: const Key('partial_refund_decline'),
          onPressed: busy
              ? null
              : () =>
                    _confirm(context, PartialRefundDecision.decline, proposal),
          child: const Text(PartialRefundProposalStrings.decline),
        ),
      ),
      primaryAction: SizedBox(
        height: 46,
        child: FilledButton(
          key: const Key('partial_refund_accept'),
          onPressed: busy
              ? null
              : () => _confirm(context, PartialRefundDecision.accept, proposal),
          child: busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.textOnBrand,
                  ),
                )
              : const Text(PartialRefundProposalStrings.accept),
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
    final c = context.tmColors;
    final proposal = state.proposal!;
    final presentation = _presentation(proposal.status, c);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          backgroundColor: presentation.background,
          borderColor: c.borderSubtle,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PartialRefundProposalStrings.bookingLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          proposal.bookingCode,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
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
                style: TextStyle(color: c.textPrimary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          child: Column(
            children: [
              AppKeyValueRow(
                label: PartialRefundProposalStrings.proposedAmount,
                value: TripFormatters.formatVnd(proposal.proposedAmount),
                isPrice: true,
                isProminent: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: c.borderSubtle),
              ),
              AppKeyValueRow(
                label: PartialRefundProposalStrings.responseDeadline,
                value: TripFormatters.formatVietnamDateTime(
                  proposal.responseDeadlineUtc,
                ),
              ),
            ],
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
_presentation(PartialRefundProposalStatus status, TripMateColors c) =>
    switch (status) {
      PartialRefundProposalStatus.awaitingTravelerResponse => (
        label: PartialRefundProposalStrings.statusAwaitingTraveler,
        description: PartialRefundProposalStrings.descriptionAwaitingTraveler,
        badgeType: StatusBadgeType.warning,
        background: c.warningContainer,
      ),
      PartialRefundProposalStatus.approved => (
        label: PartialRefundProposalStrings.statusApproved,
        description: PartialRefundProposalStrings.descriptionApproved,
        badgeType: StatusBadgeType.success,
        background: c.successContainer,
      ),
      PartialRefundProposalStatus.declined => (
        label: PartialRefundProposalStrings.statusDeclined,
        description: PartialRefundProposalStrings.descriptionDeclined,
        badgeType: StatusBadgeType.neutral,
        background: c.surfaceElevated,
      ),
      PartialRefundProposalStatus.awaitingOperatorResponse => (
        label: PartialRefundProposalStrings.statusAwaitingOperator,
        description: PartialRefundProposalStrings.descriptionAwaitingOperator,
        badgeType: StatusBadgeType.info,
        background: c.infoContainer,
      ),
      PartialRefundProposalStatus.rejected => (
        label: PartialRefundProposalStrings.statusRejected,
        description: PartialRefundProposalStrings.descriptionRejected,
        badgeType: StatusBadgeType.neutral,
        background: c.surfaceElevated,
      ),
      PartialRefundProposalStatus.expired => (
        label: PartialRefundProposalStrings.statusExpired,
        description: PartialRefundProposalStrings.descriptionExpired,
        badgeType: StatusBadgeType.neutral,
        background: c.surfaceElevated,
      ),
    };
