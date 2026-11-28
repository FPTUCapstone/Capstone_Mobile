import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
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

  /// Route name used by the page to close the sheet when the proposal ends.
  static const routeName = 'reroute-proposal-sheet';

  /// The explanation shown to the Traveler, derived from the alert code the
  /// Backend sends with the proposal.
  static String reasonText(RerouteReason reason) {
    final name = reason.affectedPoiName?.trim();
    final poi = name == null || name.isEmpty ? null : name;
    return switch (reason.code) {
      'trip_alert.severe_weather' =>
        'Dự báo thời tiết xấu tại ${poi ?? 'điểm dừng tiếp theo'}.',
      'trip_alert.poi_closure' =>
        '${poi ?? 'Điểm dừng tiếp theo'} hiện đang đóng cửa.',
      'trip_alert.schedule_delay' =>
        'Chuyến đi của bạn đang trễ so với lịch trình.',
      'trip_alert.route_deviation' => 'Bạn đã đi lệch khỏi lộ trình dự kiến.',
      _ => 'Lịch trình của bạn cần được điều chỉnh.',
    };
  }

  /// Local "HH:mm" for a planned time.
  static String formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatArrivalTimeDiff(int diffMinutes) {
    if (diffMinutes < 0) {
      return 'Sớm hơn ${diffMinutes.abs()} phút';
    } else if (diffMinutes > 0) {
      return 'Trễ hơn $diffMinutes phút';
    } else {
      return 'Không đổi giờ đến';
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
      routeSettings: const RouteSettings(name: routeName),
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
    final palette = CoastalPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.alt_route_rounded,
                    color: palette.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Đề xuất đổi lộ trình',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: palette.ink),
                    tooltip: 'Đóng mà không đổi lịch trình',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: palette.errorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: palette.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lý do đề xuất đổi tuyến',
                                style: TextStyle(
                                  color: palette.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reasonText(proposal.reason),
                                style: TextStyle(
                                  color: palette.ink,
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
                  Text(
                    'So sánh phương án',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LỘ TRÌNH HIỆN TẠI',
                                style: TextStyle(
                                  color: palette.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ...proposal.currentStops.map(
                                (stop) => _StopLine(
                                  stop: stop,
                                  isRemoved: proposal.removedStops.contains(
                                    stop.name,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: palette.softAccent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: palette.primary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'LỘ TRÌNH ĐỀ XUẤT',
                                      style: TextStyle(
                                        color: palette.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ...proposal.proposedStops.map(
                                (stop) => _StopLine(stop: stop),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ảnh hưởng dự kiến',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _MetricRow(
                          label: 'Thay đổi thời gian di chuyển',
                          value:
                              '${proposal.travelTimeDiffMinutes > 0 ? '+' : ''}${proposal.travelTimeDiffMinutes} phút',
                          isPositive: proposal.travelTimeDiffMinutes <= 0,
                        ),
                        _MetricRow(
                          label: 'Điều chỉnh giờ đến',
                          value: formatArrivalTimeDiff(
                            proposal.arrivalTimeDiffMinutes,
                          ),
                          isPositive: proposal.arrivalTimeDiffMinutes <= 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (proposal.removedStops.isNotEmpty) ...[
                    Text(
                      'Đã loại khỏi lịch trình: '
                      '${proposal.removedStops.join(', ')}',
                      style: TextStyle(color: palette.secondary, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: palette.softAccent.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 16,
                          color: palette.secondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Lịch trình chỉ thay đổi khi bạn xác nhận. Giữ lộ trình hiện tại sẽ giữ nguyên toàn bộ kế hoạch ban đầu.',
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Chấp nhận đổi lộ trình',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: palette.border),
                      backgroundColor: palette.surface,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Giữ lộ trình hiện tại',
                      style: TextStyle(
                        color: palette.ink,
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
    final palette = CoastalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.ink),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPositive ? palette.success : palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({required this.stop, this.isRemoved = false});

  final RerouteStop stop;
  final bool isRemoved;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final change = stop.change;
    final tag = switch (change) {
      RerouteStopChange.added => 'Mới',
      RerouteStopChange.moved => 'Đổi giờ',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RerouteProposalSheet.formatTime(stop.plannedArrival),
            style: TextStyle(fontSize: 12, color: palette.secondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              stop.name,
              style: TextStyle(
                fontSize: 12,
                color: isRemoved
                    ? palette.error
                    : (change == RerouteStopChange.added
                          ? palette.success
                          : palette.ink),
                fontWeight: change == null || change == RerouteStopChange.kept
                    ? FontWeight.normal
                    : FontWeight.w700,
                decoration: isRemoved ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (tag != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
