import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Captures drawing input only. Contract acceptance and submission belong to
/// the owning Cubit; this widget does not persist or upload signature bytes.
class ContractSignaturePad extends StatefulWidget {
  const ContractSignaturePad({
    required this.onChanged,
    this.disabled = false,
    super.key,
  });

  static const drawingSurfaceKey = ValueKey('contract-signature-surface');
  static const clearButtonKey = ValueKey('contract-signature-clear');

  final ValueChanged<Uint8List?> onChanged;
  final bool disabled;

  @override
  State<ContractSignaturePad> createState() => _ContractSignaturePadState();
}

class _ContractSignaturePadState extends State<ContractSignaturePad> {
  static const _exportWidth = 600;
  static const _exportHeight = 200;
  static const _maxStrokes = 128;
  static const _maxPoints = 8192;

  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  Size _surfaceSize = Size.zero;
  int _pointCount = 0;
  int _revision = 0;
  int _generation = 0;
  bool _exporting = false;
  String? _error;

  @override
  void didUpdateWidget(covariant ContractSignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disabled != oldWidget.disabled) {
      _generation++;
      _current = null;
      _exporting = false;
      _revision++;
      _pointCount = _strokes.fold(0, (sum, stroke) => sum + stroke.length);
    }
  }

  @override
  void dispose() {
    _generation++;
    _strokes.clear();
    _current = null;
    super.dispose();
  }

  Offset _normalize(Offset localPosition) => Offset(
    (localPosition.dx / _surfaceSize.width).clamp(0.0, 1.0),
    (localPosition.dy / _surfaceSize.height).clamp(0.0, 1.0),
  );

  void _start(DragStartDetails details) {
    if (widget.disabled ||
        _surfaceSize.isEmpty ||
        _strokes.length >= _maxStrokes ||
        _pointCount >= _maxPoints) {
      return;
    }
    _generation++;
    setState(() {
      _current = [_normalize(details.localPosition)];
      _pointCount++;
      _revision++;
      _exporting = false;
      _error = null;
    });
    widget.onChanged(null);
  }

  void _move(DragUpdateDetails details) {
    final current = _current;
    if (widget.disabled || current == null || _pointCount >= _maxPoints) return;
    final point = _normalize(details.localPosition);
    if ((point - current.last).distance < 0.001) return;
    setState(() {
      current.add(point);
      _pointCount++;
      _revision++;
    });
  }

  Future<void> _finish({bool cancelled = false}) async {
    final current = _current;
    if (widget.disabled || current == null) return;
    setState(() {
      if (!cancelled && current.length >= 2) {
        _strokes.add(current);
      } else {
        _pointCount -= current.length;
      }
      _current = null;
      _revision++;
    });
    if (_strokes.isEmpty) {
      widget.onChanged(null);
      return;
    }
    await _export();
  }

  void _clear() {
    if (widget.disabled) return;
    _generation++;
    setState(() {
      _strokes.clear();
      _current = null;
      _pointCount = 0;
      _revision++;
      _exporting = false;
      _error = null;
    });
    widget.onChanged(null);
  }

  Future<void> _export() async {
    final generation = ++_generation;
    final snapshot = _strokes
        .map((stroke) => List<Offset>.of(stroke))
        .toList(growable: false);
    setState(() => _exporting = true);
    ui.Picture? picture;
    ui.Image? image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _SignaturePainter.paintStrokes(
        canvas,
        Size(_exportWidth.toDouble(), _exportHeight.toDouble()),
        snapshot,
        Colors.black,
      );
      picture = recorder.endRecording();
      image = await picture.toImage(_exportWidth, _exportHeight);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted || generation != _generation || widget.disabled) return;
      if (data == null) throw StateError('PNG conversion unavailable');
      widget.onChanged(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      if (!mounted || generation != _generation || widget.disabled) return;
      setState(() => _error = 'Không thể tạo ảnh chữ ký. Vui lòng vẽ lại.');
      widget.onChanged(null);
    } finally {
      image?.dispose();
      picture?.dispose();
      if (mounted && generation == _generation) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chữ ký của bạn', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Vẽ bằng ngón tay hoặc bút trong khung bên dưới.'),
        const SizedBox(height: 12),
        Semantics(
          label: 'Vùng vẽ chữ ký',
          hint:
              'Vẽ chữ ký rồi nhấc tay để tạo ảnh. Dùng nút Xóa chữ ký để vẽ lại.',
          enabled: !widget.disabled,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _surfaceSize = constraints.biggest;
                    return GestureDetector(
                      key: ContractSignaturePad.drawingSurfaceKey,
                      behavior: HitTestBehavior.opaque,
                      onPanStart: widget.disabled ? null : _start,
                      onPanUpdate: widget.disabled ? null : _move,
                      onPanEnd: widget.disabled ? null : (_) => _finish(),
                      onPanCancel: widget.disabled
                          ? null
                          : () => _finish(cancelled: true),
                      child: CustomPaint(
                        painter: _SignaturePainter(
                          [..._strokes, ?_current],
                          colors.onSurface,
                          _revision,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        TextButton.icon(
          key: ContractSignaturePad.clearButtonKey,
          onPressed: widget.disabled ? null : _clear,
          icon: const Icon(Icons.clear),
          label: const Text('Xóa chữ ký'),
        ),
        if (_exporting)
          Semantics(
            liveRegion: true,
            child: const Text('Đang tạo ảnh chữ ký…'),
          ),
        if (_pointCount >= _maxPoints || _strokes.length >= _maxStrokes)
          const Text('Đã đạt giới hạn nét vẽ. Bạn có thể xóa để vẽ lại.'),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes, this.color, this.revision);

  final List<List<Offset>> strokes;
  final Color color;
  final int revision;

  static void paintStrokes(
    Canvas canvas,
    Size size,
    List<List<Offset>> strokes,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) =>
      paintStrokes(canvas, size, strokes, color);

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.revision != revision || oldDelegate.color != color;
}
