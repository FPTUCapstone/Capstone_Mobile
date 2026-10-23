import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';

/// Official TripMate emblem widget using the verified brand route-and-compass motif.
///
/// Clean, flat, modern presentation without glossy/glow AI artifacts.
class TripMateEmblem extends StatelessWidget {
  const TripMateEmblem({
    this.size = 64.0,
    this.isWhite = false,
    this.color,
    this.showBackground = false,
    this.backgroundColor,
    this.showGlow = false,
    super.key,
  });

  /// The dimension (width and height) of the emblem.
  final double size;

  /// Whether to render the inverted pure white emblem (e.g. for dark / green backgrounds).
  final bool isWhite;

  /// Optional color filter to apply to the emblem.
  final Color? color;

  /// Whether to render inside a flat background container.
  final bool showBackground;

  /// Background color if [showBackground] is true.
  final Color? backgroundColor;

  /// Deprecated glow parameter preserved for backwards compatibility.
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final assetPath = isWhite
        ? 'assets/images/logo/tripmate_emblem_white_512.png'
        : 'assets/images/logo/tripmate_emblem_512.png';

    final imageWidget = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: imageWidget),
      );
    }

    final borderRadius = size * 0.25;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isWhite
                ? Colors.white.withValues(alpha: 0.15)
                : AppColors.surface),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.all(size * 0.15),
      child: Center(child: imageWidget),
    );
  }
}

/// Official TripMate Brand presentation with emblem, typography, and optional tagline.
class TripMateBrand extends StatelessWidget {
  const TripMateBrand({
    this.emblemSize = 64.0,
    this.titleColor = Colors.white,
    this.subtitleColor,
    this.subtitle,
    this.isVertical = true,
    this.isWhite = false,
    super.key,
  });

  final double emblemSize;
  final Color titleColor;
  final Color? subtitleColor;
  final String? subtitle;
  final bool isVertical;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final emblem = TripMateEmblem(
      size: emblemSize,
      isWhite: isWhite || titleColor == Colors.white,
    );

    final title = Text(
      'TripMate',
      style: TextStyle(
        fontFamily: 'Geist',
        fontSize: emblemSize * 0.45,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: titleColor,
        height: 1.15,
      ),
    );

    final sub = subtitle != null
        ? Text(
            subtitle!,
            textAlign: isVertical ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: subtitleColor ?? titleColor.withValues(alpha: 0.8),
              letterSpacing: 0.2,
              height: 1.3,
            ),
          )
        : null;

    if (!isVertical) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          emblem,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              if (sub != null) ...[const SizedBox(height: 2), sub],
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        emblem,
        const SizedBox(height: 16),
        title,
        if (sub != null) ...[const SizedBox(height: 8), sub],
      ],
    );
  }
}

/// Comprehensive TripMate Logo helper widget.
class TripMateLogo extends StatelessWidget {
  const TripMateLogo.full({
    this.width,
    this.height = 32.0,
    this.isWhite = false,
    this.fit = BoxFit.contain,
    super.key,
  }) : _type = _LogoType.full,
       size = 0,
       color = null;

  const TripMateLogo.emblem({
    this.size = 48.0,
    this.isWhite = false,
    this.color,
    this.fit = BoxFit.contain,
    super.key,
  }) : _type = _LogoType.emblem,
       width = size,
       height = size;

  const TripMateLogo.wordmark({
    this.width,
    this.height = 24.0,
    this.isWhite = false,
    this.fit = BoxFit.contain,
    super.key,
  }) : _type = _LogoType.wordmark,
       size = 0,
       color = null;

  final _LogoType _type;
  final double? width;
  final double? height;
  final double size;
  final bool isWhite;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = switch (_type) {
      _LogoType.full =>
        isWhite
            ? 'assets/images/logo/tripmate_logo_full_white_512.png'
            : 'assets/images/logo/tripmate_logo_full_512.png',
      _LogoType.emblem =>
        isWhite
            ? 'assets/images/logo/tripmate_emblem_white_512.png'
            : 'assets/images/logo/tripmate_emblem_512.png',
      _LogoType.wordmark =>
        isWhite
            ? 'assets/images/logo/tripmate_wordmark_white.svg' // fallback handled by image if PNG
            : 'assets/images/logo/tripmate_wordmark.svg',
    };

    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      color: color,
    );
  }
}

enum _LogoType { full, emblem, wordmark }
