import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';

class NavigationMapCanvas extends StatelessWidget {
  const NavigationMapCanvas({
    super.key,
    required this.items,
    required this.targetItemId,
    this.hasRerouteProposal = false,
    this.isDeviation = false,
    this.showNotice = true,
  });

  final List<NavigationSessionItem> items;
  final int? targetItemId;
  final bool hasRerouteProposal;
  final bool isDeviation;

  /// The page shows [NavigationMapPreviewNotice] below its own header instead,
  /// where the header cannot cover it.
  final bool showNotice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Custom vector canvas painter
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _MapCanvasPainter(
                items: items,
                targetItemId: targetItemId,
                hasRerouteProposal: hasRerouteProposal,
                isDeviation: isDeviation,
              ),
            ),

            if (showNotice)
              const Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Center(child: NavigationMapPreviewNotice()),
              ),
          ],
        );
      },
    );
  }
}

/// "Mapbox not configured" notice for the illustration map.
class NavigationMapPreviewNotice extends StatelessWidget {
  const NavigationMapPreviewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              'MAPBOX NOT CONFIGURED — Illustration Preview Only',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  _MapCanvasPainter({
    required this.items,
    required this.targetItemId,
    required this.hasRerouteProposal,
    required this.isDeviation,
  });

  final List<NavigationSessionItem> items;
  final int? targetItemId;
  final bool hasRerouteProposal;
  final bool isDeviation;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Map land background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEFF3F8),
    );

    // 2. Simplified decorative road network / river
    final waterPaint = Paint()..color = const Color(0xFFD6E4F0);
    final waterPath = Path()
      ..moveTo(size.width * 0.75, 0)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.45,
        size.width * 0.8,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    final bgRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final bgRoadPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.35,
        size.width,
        size.height * 0.6,
      )
      ..moveTo(size.width * 0.3, size.height)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.5,
        size.width * 0.7,
        0,
      );
    canvas.drawPath(bgRoadPath, bgRoadPaint);

    // 3. Planned Route Polyline
    final activeRoutePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Illustrative layout only: the user start followed by one point per stop.
    final stopCount = items.isEmpty ? 1 : items.length;
    final routePoints = [
      Offset(size.width * 0.2, size.height * 0.75),
      for (var i = 1; i <= stopCount; i++)
        Offset(
          size.width * (0.2 + 0.62 * i / stopCount),
          size.height * (0.75 - 0.57 * i / stopCount),
        ),
    ];

    final routePath = Path()..moveTo(routePoints[0].dx, routePoints[0].dy);
    for (var i = 1; i < routePoints.length; i++) {
      routePath.lineTo(routePoints[i].dx, routePoints[i].dy);
    }
    canvas.drawPath(routePath, activeRoutePaint);

    // 4. Proposed Reroute Segment (if reroute proposal is active)
    if (hasRerouteProposal && routePoints.length > 4) {
      final proposedPaint = Paint()
        ..color = AppColors.success
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Alternative branch diverting at Stop 3 toward safe shelter
      final reroutePath = Path()
        ..moveTo(routePoints[3].dx, routePoints[3].dy)
        ..quadraticBezierTo(
          size.width * 0.75,
          size.height * 0.45,
          size.width * 0.82,
          size.height * 0.18,
        );
      canvas.drawPath(reroutePath, proposedPaint);

      // Affected segment marked with dashed/warning styling
      final affectedSegmentPaint = Paint()
        ..color = AppColors.error.withValues(alpha: 0.6)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;

      canvas.drawLine(routePoints[3], routePoints[4], affectedSegmentPaint);
    }

    // 5. Off-route deviation indicator (if active)
    if (isDeviation) {
      final deviationPoint = Offset(
        size.width * 0.12,
        size.height * 0.82,
      ); // Off-track user position
      final deviationDashedPaint = Paint()
        ..color = AppColors.error
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      canvas.drawLine(routePoints[0], deviationPoint, deviationDashedPaint);
    }

    // 6. Draw Waypoint Markers
    for (var i = 1; i < routePoints.length && i <= items.length; i++) {
      final pt = routePoints[i];
      final item = items[i - 1];
      final isCurrent = item.itemId == targetItemId;

      // Marker circle
      final markerPaint = Paint()
        ..color = isCurrent
            ? AppColors.secondary
            : switch (item.status) {
                NavigationItemStatus.reached => AppColors.muted,
                NavigationItemStatus.skipped => AppColors.warning,
                NavigationItemStatus.pending => AppColors.primary,
              };
      canvas.drawCircle(pt, isCurrent ? 14 : 11, markerPaint);

      // Border ring
      canvas.drawCircle(
        pt,
        isCurrent ? 14 : 11,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );

      // Pin number label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${item.displayNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(pt.dx - textPainter.width / 2, pt.dy - textPainter.height / 2),
      );
    }

    // 7. Draw User GPS Position Marker
    final userPos = routePoints[0];

    // Pulsing halo
    canvas.drawCircle(
      userPos,
      18,
      Paint()..color = AppColors.primary.withValues(alpha: 0.2),
    );

    // Inner location circle
    canvas.drawCircle(userPos, 8, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      userPos,
      8,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.targetItemId != targetItemId ||
        oldDelegate.items != items ||
        oldDelegate.hasRerouteProposal != hasRerouteProposal ||
        oldDelegate.isDeviation != isDeviation;
  }
}
