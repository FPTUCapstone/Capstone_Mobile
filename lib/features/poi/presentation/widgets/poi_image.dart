import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';

class PoiImage extends StatelessWidget {
  const PoiImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return const _Placeholder();

    return Image.network(
      imageUrl,
      fit: fit,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: frame == null ? const _Placeholder(isShimmer: true) : child,
        );
      },
      errorBuilder: (_, _, _) => const _Placeholder(),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const _Placeholder(isShimmer: true);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.isShimmer = false});

  final bool isShimmer;

  @override
  Widget build(BuildContext context) {
    if (isShimmer) {
      return const AppShimmer(
        child: ColoredBox(color: Color(0xFFE2E8F0), child: SizedBox.expand()),
      );
    }

    return const ColoredBox(
      color: PoiPalette.tealSoft,
      child: Center(
        child: Icon(Icons.landscape_outlined, color: PoiPalette.teal, size: 32),
      ),
    );
  }
}
