import 'package:flutter/material.dart';

/// MOTION-02: Subtle photographic parallax using native [Flow] + [FlowDelegate].
///
/// Images translate slower than scrolling content during vertical scroll,
/// clipped strictly within the card image bounds, causing zero parent widget
/// rebuilds and zero text movement.
class EditorialParallaxImage extends StatelessWidget {
  EditorialParallaxImage({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    this.enabled = true,
    this.reduceMotion = false,
    this.axis = Axis.vertical,
    this.maxDisplacement = 10.0,
    this.cacheWidth,
  }) : _frameKey = GlobalKey();

  final String imageUrl;
  final String semanticLabel;
  final bool enabled;
  final bool reduceMotion;
  final Axis axis;
  final double maxDisplacement;
  final int? cacheWidth;
  final GlobalKey _frameKey;

  Widget _buildImage() {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        semanticLabel: semanticLabel,
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim =
        reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !enabled;

    if (disableAnim) {
      return ClipRect(child: _buildImage());
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      return ClipRect(child: _buildImage());
    }

    return RepaintBoundary(
      child: ClipRect(
        child: Flow(
          key: _frameKey,
          delegate: _ParallaxFlowDelegate(
            scrollable: scrollable,
            frameKey: _frameKey,
            axis: axis,
            maxDisplacement: maxDisplacement.clamp(0.0, 12.0),
          ),
          children: [_buildImage()],
        ),
      ),
    );
  }
}

class _ParallaxFlowDelegate extends FlowDelegate {
  _ParallaxFlowDelegate({
    required this.scrollable,
    required this.frameKey,
    required this.axis,
    required this.maxDisplacement,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final GlobalKey frameKey;
  final Axis axis;
  final double maxDisplacement;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    if (axis == Axis.vertical) {
      return BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: constraints.maxHeight + maxDisplacement * 2,
      );
    }
    return BoxConstraints.tightFor(
      width: constraints.maxWidth + maxDisplacement * 2,
      height: constraints.maxHeight,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final scrollableRender = scrollable.context.findRenderObject();
    final itemRender = frameKey.currentContext?.findRenderObject();
    if (scrollableRender is! RenderBox ||
        itemRender is! RenderBox ||
        !scrollableRender.hasSize ||
        !itemRender.hasSize) {
      context.paintChild(0);
      return;
    }

    final viewportSize = scrollableRender.size;
    final itemOrigin = itemRender.localToGlobal(
      itemRender.size.center(Offset.zero),
      ancestor: scrollableRender,
    );

    if (axis == Axis.vertical) {
      final viewportCenter = viewportSize.height * 0.5;
      final normalized = viewportCenter > 0
          ? ((itemOrigin.dy - viewportCenter) / viewportCenter).clamp(-1.0, 1.0)
          : 0.0;
      final dy = -maxDisplacement - (normalized * maxDisplacement);
      context.paintChild(0, transform: Matrix4.translationValues(0, dy, 0));
    } else {
      final viewportCenter = viewportSize.width * 0.5;
      final normalized = viewportCenter > 0
          ? ((itemOrigin.dx - viewportCenter) / viewportCenter).clamp(-1.0, 1.0)
          : 0.0;
      final dx = -maxDisplacement - (normalized * maxDisplacement);
      context.paintChild(0, transform: Matrix4.translationValues(dx, 0, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _ParallaxFlowDelegate oldDelegate) {
    return scrollable != oldDelegate.scrollable ||
        axis != oldDelegate.axis ||
        maxDisplacement != oldDelegate.maxDisplacement;
  }
}
