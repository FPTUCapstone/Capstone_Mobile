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

/// Formats tour price with currency integrity.
///
/// For VND, formats as Vietnamese Dong using [TripFormatters.formatCurrencyVnd].
/// For non-VND or unsupported currencies, formats the numeric amount with thousand
/// separators and appends the explicit currency code, preventing silent mislabeling.
String formatTourDiscoveryPrice(int amount, [String currency = 'VND']) {
  final upper = currency.toUpperCase().trim();
  if (upper == 'VND' || upper.isEmpty) {
    return TripFormatters.formatCurrencyVnd(amount);
  }
  final s = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(s[i]);
  }
  return '${buffer.toString()} $upper';
}

class PriceAnchor extends StatelessWidget {
  const PriceAnchor({
    super.key,
    required this.priceVnd,
    required this.alignEnd,
    this.currency = 'VND',
  });

  final int priceVnd;
  final bool alignEnd;
  final String currency;

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
          formatTourDiscoveryPrice(priceVnd, currency),
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
    this.currency = 'VND',
    this.showUnit = true,
  });

  final int priceVnd;
  final String currency;
  final bool showUnit;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final formattedPrice = formatTourDiscoveryPrice(priceVnd, currency);
    if (!showUnit) {
      return Text(
        formattedPrice,
        style: AppTypography.price(c.brandTeal, fontSize: 15.5),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formattedPrice,
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
