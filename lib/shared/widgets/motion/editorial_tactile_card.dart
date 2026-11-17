import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// MOTION-03: Calm tactile press interaction (`0.985` scale, `110ms` press,
/// `180ms` release, ripple + haptic feedback, preserves scroll & `onTap`).
class EditorialTactileCard extends StatefulWidget {
  const EditorialTactileCard({
    super.key,
    required this.onTap,
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.semanticLabel,
    required this.child,
    this.enabled = true,
    this.reduceMotion = false,
    this.semanticsButton = true,
  });

  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final bool enabled;
  final bool reduceMotion;
  final String semanticLabel;
  final Widget child;
  final bool semanticsButton;

  @override
  State<EditorialTactileCard> createState() => _EditorialTactileCardState();
}

class _EditorialTactileCardState extends State<EditorialTactileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 180),
  );

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.985)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutCubic,
        ),
      );

  int? _activePointer;
  Offset? _downPosition;
  bool _dragCanceled = false;

  bool _resolveDisableMotion() =>
      widget.reduceMotion ||
      (mounted
          ? (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
          : false);

  bool get _skipMotion => !widget.enabled || _resolveDisableMotion();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_skipMotion && _controller.value != 0.0) {
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _dragCanceled = false;
    if (_skipMotion || _activePointer != null) return;
    _activePointer = event.pointer;
    _downPosition = event.position;
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _downPosition == null) return;
    if ((event.position - _downPosition!).distance > 8.0) {
      _dragCanceled = true;
      _cancelPress();
    }
  }

  void _cancelPress() {
    _activePointer = null;
    _downPosition = null;
    if (!mounted) return;
    if (_skipMotion) {
      _controller.value = 0.0;
      return;
    }
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final skip = _skipMotion;
    final body = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (e) {
        if (e.pointer == _activePointer) _cancelPress();
      },
      onPointerCancel: (e) {
        if (e.pointer == _activePointer) _cancelPress();
      },
      child: Material(
        color: widget.backgroundColor,
        borderRadius: widget.borderRadius,
        child: InkWell(
          onTap: () {
            if (_dragCanceled) return;
            _cancelPress();
            widget.onTap();
          },
          borderRadius: widget.borderRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(color: widget.borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.child,
          ),
        ),
      ),
    );

    final scaled = skip ? body : ScaleTransition(scale: _scale, child: body);

    return RepaintBoundary(
      child: Semantics(
        button: widget.semanticsButton,
        label: widget.semanticLabel,
        child: scaled,
      ),
    );
  }
}
