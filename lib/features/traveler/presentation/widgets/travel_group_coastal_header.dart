import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';

/// Shared Coastal Deep Teal header surface inspired by the E-Ticket boarding
/// pass, overlaid with a subtle dashed route & waypoint motif.
final class CoastalRoutePassHeader extends StatelessWidget {
  const CoastalRoutePassHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 18),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondaryDark, AppColors.primary],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CoastalRouteMotifPainter()),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (borderRadius == null) return content;
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}

final class _CoastalRouteMotifPainter extends CustomPainter {
  const _CoastalRouteMotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final primaryPath = Path()
      ..moveTo(-8, size.height * 0.84)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.60,
        size.width * 0.28,
        size.height * 0.18,
        size.width * 0.50,
        size.height * 0.36,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.52,
        size.width * 0.82,
        size.height * 0.14,
        size.width + 8,
        size.height * 0.26,
      );

    for (final metric in primaryPath.computeMetrics()) {
      const dash = 4.5;
      const gap = 5.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), dashedPaint);
        distance += dash + gap;
      }
    }

    final secondaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final secondaryPath = Path()
      ..moveTo(-8, size.height * 0.94)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.78,
        size.width * 0.42,
        size.height * 0.56,
        size.width * 0.68,
        size.height * 0.66,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.72,
        size.width * 0.92,
        size.height * 0.52,
        size.width + 8,
        size.height * 0.48,
      );
    canvas.drawPath(secondaryPath, secondaryPaint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final centerStop = Offset(size.width * 0.50, size.height * 0.36);
    canvas.drawCircle(centerStop, 3.5, dotPaint);
    canvas.drawCircle(centerStop, 8.0, ringPaint);
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.22),
      2.8,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.52),
      2.4,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Boarding-pass tear divider with side notch cutouts matching the Coastal canvas.
final class CoastalPassDivider extends StatelessWidget {
  const CoastalPassDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: const _DashedLinePainter(),
            ),
          ),
          Positioned(left: -9, child: _notch()),
          Positioned(right: -9, child: _notch()),
        ],
      ),
    );
  }

  static Widget _notch() => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: AppColors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.line),
    ),
  );
}

final class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCFD8D3)
      ..strokeWidth = 1.1;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Extracts up to two Vietnamese/Latin initials (preferring last two words).
String groupMemberInitials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  final first = parts[parts.length - 2].substring(0, 1).toUpperCase();
  final last = parts.last.substring(0, 1).toUpperCase();
  return '$first$last';
}

/// Circular avatar for travel group members using real [avatarUrl] when set,
/// or clean Coastal Heritage initials fallback.
final class GroupMemberAvatar extends StatelessWidget {
  const GroupMemberAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isHost = false,
    this.radius = 20,
    this.borderColor,
  });

  final String displayName;
  final String? avatarUrl;
  final bool isHost;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final initials = groupMemberInitials(displayName);
    final bg = isHost ? AppColors.primary : AppColors.primarySoft;
    final fg = isHost ? Colors.white : AppColors.primary;
    final cleanUrl = avatarUrl?.trim();

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: cleanUrl == null || cleanUrl.isEmpty
          ? null
          : NetworkImage(cleanUrl),
      child: cleanUrl != null && cleanUrl.isNotEmpty
          ? null
          : initials.isEmpty
          ? Icon(Icons.person_outline, color: fg, size: radius)
          : Text(
              initials,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.65,
                letterSpacing: -0.2,
              ),
            ),
    );

    if (borderColor != null) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2),
        ),
        child: avatar,
      );
    }
    return avatar;
  }
}
