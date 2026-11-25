import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

class TripAlertBanner extends StatelessWidget {
  const TripAlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    this.onOpen,
    this.onReviewReroute,
    this.onConfirmArrival,
    this.onDepartStop,
    this.onSkipAffectedStop,
  });

  final TripAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;
  final VoidCallback? onReviewReroute;
  final VoidCallback? onConfirmArrival;
  final VoidCallback? onDepartStop;
  final VoidCallback? onSkipAffectedStop;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final (
      accentColor,
      bgColor,
      borderColor,
      icon,
      severityLabel,
    ) = switch (alert.severity) {
      AlertSeverity.critical => (
        palette.error,
        palette.errorBg,
        palette.error.withValues(alpha: 0.35),
        Icons.warning_amber_rounded,
        'CẢNH BÁO KHẨN',
      ),
      AlertSeverity.warning => (
        palette.warningText,
        palette.warningBg,
        palette.warningBorder,
        Icons.schedule_rounded,
        alert.isOverstay ? 'CẢNH BÁO · QUÁ GIỜ DỪNG' : 'CẢNH BÁO',
      ),
      AlertSeverity.info => (
        palette.primary,
        palette.softAccent,
        palette.border,
        Icons.info_outline_rounded,
        'THÔNG BÁO',
      ),
    };

    final actions = <Widget>[
      if (onOpen != null)
        OutlinedButton(
          onPressed: onOpen,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.ink,
            backgroundColor: palette.surface.withValues(alpha: 0.8),
            side: BorderSide(color: borderColor),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Xem cảnh báo'),
        ),
      if (alert.type == TripAlertType.delay &&
          !alert.isOverstay &&
          onConfirmArrival != null)
        FilledButton(
          onPressed: onConfirmArrival,
          style: FilledButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Xác nhận đã đến'),
        ),
      if (alert.isOverstay && onDepartStop != null)
        FilledButton(
          onPressed: onDepartStop,
          style: FilledButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rời điểm ngay'),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14),
            ],
          ),
        ),
      if (alert.messageCode == 'trip_alert.severe_weather' &&
          alert.canSkipAffectedStop &&
          onSkipAffectedStop != null)
        OutlinedButton(
          onPressed: onSkipAffectedStop,
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Bỏ qua điểm này'),
        ),
      if (alert.rerouteProposalAvailable && onReviewReroute != null)
        FilledButton(
          onPressed: onReviewReroute,
          style: FilledButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Xem đề xuất đổi tuyến'),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14),
            ],
          ),
        ),
    ];

    return Semantics(
      container: true,
      label: '$severityLabel: ${alert.title}. ${alert.description}',
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: palette.ink.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: accentColor, size: 17),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              severityLabel,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: palette.ink,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 30,
                              height: 30,
                            ),
                            tooltip: 'Đóng cảnh báo',
                            onPressed: onDismiss,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.ink.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 6, children: actions),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
