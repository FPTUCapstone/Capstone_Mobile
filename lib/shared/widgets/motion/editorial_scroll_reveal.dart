import 'package:flutter/material.dart';

/// Persists once-per-item reveal completion above scrollable/sliver lifetimes
/// so scrolling away and back never replays MOTION-01 entrance animations.
class TourRevealCoordinator {
  final Set<String> _revealedIds = <String>{};

  bool hasRevealed(String id) => _revealedIds.contains(id);

  void markRevealed(String id) {
    _revealedIds.add(id);
  }

  void resetAll() {
    _revealedIds.clear();
  }
}

/// MOTION-01: Scroll-triggered card reveal.
///
/// - Initial opacity: `0.0` -> target `1.0`
/// - Initial Y offset: `16.0` logical pixels -> `0.0`
/// - Duration: `400ms` (`380–420ms` window), `Curves.easeOutCubic`
/// - Stagger between simultaneously entering cards: `80ms`
/// - Reveals strictly once per [itemKey] in [coordinator]
/// - Respects `MediaQuery.disableAnimationsOf(context)` / [reduceMotion]
class EditorialScrollReveal extends StatefulWidget {
  const EditorialScrollReveal({
    super.key,
    required this.itemKey,
    required this.coordinator,
    required this.child,
    this.enabled = true,
    this.reduceMotion = false,
    this.staggerIndex = 0,
  });

  final String itemKey;
  final TourRevealCoordinator coordinator;
  final Widget child;
  final bool enabled;
  final bool reduceMotion;
  final int staggerIndex;

  @override
  State<EditorialScrollReveal> createState() => _EditorialScrollRevealState();
}

class _EditorialScrollRevealState extends State<EditorialScrollReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curve;
  ScrollPosition? _scrollPosition;
  bool _scheduledDelay = false;
  bool _triggered = false;
  bool _postFramePending = false;

  bool _resolveDisableMotion() =>
      widget.reduceMotion ||
      (mounted
          ? (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
          : false);

  bool get _skipMotion =>
      !widget.enabled ||
      _resolveDisableMotion() ||
      widget.coordinator.hasRevealed(widget.itemKey);

  @override
  void initState() {
    super.initState();
    if (!widget.enabled ||
        widget.reduceMotion ||
        widget.coordinator.hasRevealed(widget.itemKey)) {
      _triggered = true;
      widget.coordinator.markRevealed(widget.itemKey);
      return;
    }
    _initControllerIfNeeded();
  }

  void _initControllerIfNeeded() {
    if (_controller != null) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _curve = CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolveDisableMotion() && !_triggered) {
      _snapRevealed();
    }
    _attachScrollListener();
    _scheduleViewportCheck();
  }

  @override
  void didUpdateWidget(covariant EditorialScrollReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemKey != widget.itemKey ||
        (!widget.coordinator.hasRevealed(widget.itemKey) && _triggered)) {
      _triggered = widget.coordinator.hasRevealed(widget.itemKey);
      _scheduledDelay = false;
      if (!_triggered && !_skipMotion) {
        _initControllerIfNeeded();
        _controller?.value = 0.0;
        _scheduleViewportCheck();
      }
    }
    if (_resolveDisableMotion() && !_triggered) {
      _snapRevealed();
    }
  }

  void _attachScrollListener() {
    final nextPos = Scrollable.maybeOf(context)?.position;
    if (nextPos == _scrollPosition) return;
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = nextPos;
    _scrollPosition?.addListener(_onScroll);
  }

  void _scheduleViewportCheck() {
    if (_postFramePending || _triggered || _scheduledDelay) return;
    _postFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFramePending = false;
      _checkViewportEntry();
    });
  }

  void _onScroll() {
    if (_triggered || _scheduledDelay) return;
    _checkViewportEntry();
    _scheduleViewportCheck();
  }

  void _snapRevealed() {
    _triggered = true;
    widget.coordinator.markRevealed(widget.itemKey);
    _controller?.value = 1.0;
    if (mounted) setState(() {});
  }

  void _checkViewportEntry() {
    if (!mounted || _triggered || _scheduledDelay) return;
    if (_resolveDisableMotion() || !widget.enabled) {
      _snapRevealed();
      return;
    }

    final renderObj = context.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return;

    final scrollableBox =
        Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null || !scrollableBox.hasSize) {
      _startReveal();
      return;
    }

    final topLeft = renderObj.localToGlobal(
      Offset.zero,
      ancestor: scrollableBox,
    );
    final viewportHeight = scrollableBox.size.height;
    final boxHeight = renderObj.size.height;
    final visible =
        topLeft.dy <= viewportHeight - 16 &&
        topLeft.dy + boxHeight >= -boxHeight * 0.25;
    if (visible) {
      _startReveal();
    }
  }

  void _startReveal() {
    if (_triggered || _scheduledDelay) return;
    final delayMs = widget.staggerIndex.clamp(0, 4) * 80;
    if (delayMs == 0) {
      _runAnimation();
      return;
    }
    _scheduledDelay = true;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted || _triggered) return;
      _runAnimation();
    });
  }

  void _runAnimation() {
    if (_triggered) return;
    _triggered = true;
    widget.coordinator.markRevealed(widget.itemKey);
    if (_resolveDisableMotion()) {
      _controller?.value = 1.0;
      return;
    }
    _controller?.forward();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = _resolveDisableMotion() || !widget.enabled;
    if (disableAnim || _controller == null) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _curve!,
      child: AnimatedBuilder(
        animation: _curve!,
        child: widget.child,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 16.0 * (1.0 - _curve!.value)),
            child: child,
          );
        },
      ),
    );
  }
}
