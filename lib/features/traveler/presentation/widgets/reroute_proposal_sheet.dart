import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';

class RerouteProposalSheet extends StatelessWidget {
  const RerouteProposalSheet({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  });

  final RerouteProposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onClose;

  static String formatArrivalTimeDiff(int diffMinutes) {
    if (diffMinutes < 0) {
      return '${diffMinutes.abs()} min earlier';
    } else if (diffMinutes > 0) {
      return '$diffMinutes min later';
    } else {
      return 'No arrival-time change';
    }
  }

  static Future<void> show(
    BuildContext context, {
    required RerouteProposal proposal,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    required VoidCallback onClose,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RerouteProposalSheet(
        proposal: proposal,
        onAccept: () {
          Navigator.of(sheetContext).pop();
          onAccept();
        },
        onDecline: () {
          Navigator.of(sheetContext).pop();
          onDecline();
        },
        onClose: () {
          Navigator.of(sheetContext).pop();
        },
      ),
    ).whenComplete(() {
      onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Suggested Route Change',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close without changing plan',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Disruption Reason Alert Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEF),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reason for Re-routing',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                proposal.reason,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Side-by-Side Comparison of Current vs Proposed
                  Text(
                    'Compare Route Options',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Plan Column
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT PLAN',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ...proposal.currentStops.map(
                                (stop) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    stop,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          stop.contains('Heavy Rain') ||
                                              stop.contains('Outdoor')
                                          ? AppColors.error
                                          : AppColors.ink,
                                      fontWeight: stop.contains('Heavy Rain')
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Proposed Plan Column
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF1FE),
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'PROPOSED PLAN',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ...proposal.proposedStops.map(
                                (stop) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    stop,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          stop.contains('Shelter') ||
                                              stop.contains('Indoor')
                                          ? AppColors.success
                                          : AppColors.ink,
                                      fontWeight:
                                          stop.contains('Shelter') ||
                                              stop.contains('Indoor')
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Impact Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Impact',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _MetricRow(
                            label: 'Travel time change',
                            value:
                                '${proposal.travelTimeDiffMinutes > 0 ? '+' : ''}${proposal.travelTimeDiffMinutes} min',
                            isPositive: proposal.travelTimeDiffMinutes <= 0,
                          ),
                          _MetricRow(
                            label: 'Arrival time adjustment',
                            value: formatArrivalTimeDiff(
                              proposal.arrivalTimeDiffMinutes,
                            ),
                            isPositive: proposal.arrivalTimeDiffMinutes <= 0,
                          ),
                          if (proposal.distanceDiffKm != null)
                            _MetricRow(
                              label: 'Distance difference (Demo)',
                              value:
                                  '+${proposal.distanceDiffKm!.toStringAsFixed(1)} km',
                              isPositive: false,
                            ),
                          if (proposal.costDiffVnd != null)
                            _MetricRow(
                              label: 'Entry fee difference (Demo)',
                              value:
                                  '${proposal.costDiffVnd! < 0 ? '-' : '+'}₫ 50,000',
                              isPositive: proposal.costDiffVnd! <= 0,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Important Consent Notice
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FC),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.security_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Nothing changes until you accept. Keeping the current route leaves your itinerary exactly as planned.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Fixed Action Buttons
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text(
                      'Accept Re-routing',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: const Text(
                      'Keep Current Route',
                      style: TextStyle(
                        color: AppColors.ink,
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
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final String label;
  final String value;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.success : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
