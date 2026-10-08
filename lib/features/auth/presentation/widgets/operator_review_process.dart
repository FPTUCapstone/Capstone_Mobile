import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/section_card.dart';

/// Generic guidance about how a Tour Operator application is reviewed.
///
/// It carries no dates, durations, counters or per-application milestones.
/// [currentStep] may only be set from an authoritative status (for example a
/// session status of Pending approval marks the review step as current); no
/// step is ever shown as completed.
class OperatorReviewProcess extends StatelessWidget {
  const OperatorReviewProcess({this.currentStep, super.key});

  static const steps = [
    'Application',
    'Administrator review',
    'Operator access',
  ];

  /// Index into [steps] of the step that the real status says is in progress.
  final int? currentStep;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.route_outlined,
      title: 'Review process',
      child: Column(
        children: [
          for (final (index, label) in steps.indexed)
            _ProcessStep(
              number: index + 1,
              label: label,
              isCurrent: index == currentStep,
              isLast: index == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.number,
    required this.label,
    required this.isCurrent,
    required this.isLast,
  });

  final bool isCurrent;
  final bool isLast;
  final String label;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                  ),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: Text(
                        '$number',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCurrent
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: SizedBox(
                      width: 2,
                      child: ColoredBox(color: scheme.outlineVariant),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2,
                bottom: isLast ? 0 : AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCurrent ? scheme.secondary : scheme.onSurface,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (isCurrent)
                    Text(
                      'Current status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
