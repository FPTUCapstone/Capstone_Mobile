import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';

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
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => const _Placeholder(),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const _Placeholder(showProgress: true),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PoiPalette.tealSoft,
      child: Center(
        child: showProgress
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.landscape_outlined,
                color: PoiPalette.teal,
                size: 32,
              ),
      ),
    );
  }
}
