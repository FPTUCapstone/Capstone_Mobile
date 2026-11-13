import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

class RatingInline extends StatelessWidget {
  const RatingInline({super.key, required this.rating, this.fontSize = 12});

  final double rating;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: fontSize + 2.5,
          color: c.isDark ? c.warning : const Color(0xFFD97706),
        ),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: AppTypography.uiFont,
            color: c.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class OperatorAndScheduleMeta extends StatelessWidget {
  const OperatorAndScheduleMeta({
    super.key,
    required this.operatorName,
    required this.scheduleText,
    required this.isSoldOut,
  });

  final String operatorName;
  final String scheduleText;
  final bool isSoldOut;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          operatorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.uiFont,
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          scheduleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.uiFont,
            color: isSoldOut ? c.error : c.textSecondary,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class PriceAnchor extends StatelessWidget {
  const PriceAnchor({
    super.key,
    required this.priceVnd,
    required this.alignEnd,
  });

  final int priceVnd;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Giá từ · / khách',
          style: TextStyle(
            fontFamily: AppTypography.uiFont,
            color: c.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          TripFormatters.formatCurrencyVnd(priceVnd),
          style: AppTypography.price(c.brandTeal, fontSize: 17.5),
        ),
      ],
    );
  }
}

class InlinePriceWithUnit extends StatelessWidget {
  const InlinePriceWithUnit({
    super.key,
    required this.priceVnd,
    this.showUnit = true,
  });

  final int priceVnd;
  final bool showUnit;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    if (!showUnit) {
      return Text(
        TripFormatters.formatCurrencyVnd(priceVnd),
        style: AppTypography.price(c.brandTeal, fontSize: 15.5),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          TripFormatters.formatCurrencyVnd(priceVnd),
          style: AppTypography.price(c.brandTeal, fontSize: 15.5),
        ),
        const SizedBox(width: 4),
        Text(
          '/ khách',
          style: TextStyle(
            fontFamily: AppTypography.uiFont,
            color: c.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
