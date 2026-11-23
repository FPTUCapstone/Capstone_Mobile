import 'package:flutter/services.dart';

/// The app-owned Android bridge retains the native SDK cancellation handles.
/// It also avoids the pinned Flutter plugin's persisted style-byte conversion.
class OfflineMapDataSource {
  OfflineMapDataSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.tripmate.trip_mate_mobile/offline_map';
  final MethodChannel _channel;
  Future<void>? _initialization;
  _OfflineDownloadOperation? _operation;

  Future<void> initialize() => _initialization ??= _channel
      .invokeMethod<void>('initialize')
      .catchError((Object error) {
        _initialization = null;
        throw error;
      });

  Future<Map<String, Object?>> storage() async {
    await initialize();
    final value = await _channel.invokeMapMethod<String, Object?>('storage');
    if (value == null) throw const FormatException('Missing offline storage');
    return value;
  }

  /// An estimate, not a storage guarantee. Null means the provider could not
  /// estimate the complete map data (for example, the style is not saved yet).
  Future<int?> estimate({
    required String regionId,
    required Map<String, Object?> geometry,
  }) async {
    if (_operation != null) {
      throw StateError('An offline map operation is active');
    }
    final operation = _OfflineDownloadOperation();
    _operation = operation;
    try {
      await initialize();
      _throwIfCancelled(operation);
      final value = await _channel.invokeMethod<int>('estimate', {
        'regionId': regionId,
        'geometry': geometry,
      });
      _throwIfCancelled(operation);
      if (value != null && value < 0) {
        throw const FormatException('Invalid offline map estimate');
      }
      return value;
    } finally {
      if (identical(_operation, operation)) _operation = null;
    }
  }

  Future<OfflineMapDownload> download({
    required String regionId,
    required Map<String, Object?> geometry,
    required int maxBytes,
    void Function(int completedBytes, int completedCount, int requiredCount)?
    onProgress,
  }) async {
    if (_operation != null) {
      throw StateError('An offline map download is active');
    }
    final operation = _OfflineDownloadOperation();
    _operation = operation;
    try {
      await initialize();
      _throwIfCancelled(operation);
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'progress') return;
        final value = Map<String, Object?>.from(call.arguments as Map);
        if (value['regionId'] == regionId) {
          onProgress?.call(
            (value['bytes'] as num).toInt(),
            (value['completed'] as num).toInt(),
            (value['required'] as num).toInt(),
          );
        }
      });
      try {
        final downloaded = OfflineMapDownload.fromNative(
          await _channel.invokeMapMethod<String, Object?>('download', {
            'regionId': regionId,
            'geometry': geometry,
            'minZoom': 10,
            'maxZoom': 16,
            'maxBytes': maxBytes,
          }),
        );
        if (downloaded.regionId != regionId) {
          throw const FormatException('Offline map generation did not match');
        }
        // Native completion can race a cancel sent while its response is in
        // transit. Do not publish that generation; release our own new region.
        if (operation.cancelled) {
          await remove(regionId);
          _throwIfCancelled(operation);
        }
        return downloaded;
      } finally {
        _channel.setMethodCallHandler(null);
      }
    } finally {
      if (identical(_operation, operation)) _operation = null;
    }
  }

  Future<void> cancel() async {
    // Latch before awaiting native work: initialization may still be pending,
    // so the native side does not necessarily have a job to cancel yet.
    _operation?.cancelled = true;
    await _channel.invokeMethod<void>('cancel');
  }

  static void _throwIfCancelled(_OfflineDownloadOperation operation) {
    if (operation.cancelled) {
      throw PlatformException(
        code: 'cancelled',
        message: 'Offline download cancelled',
      );
    }
  }

  Future<OfflineMapDownload> verify(String regionId) async {
    await initialize();
    return OfflineMapDownload.fromNative(
      await _channel.invokeMapMethod<String, Object?>('verify', {
        'regionId': regionId,
      }),
    );
  }

  Future<void> remove(String regionId) async {
    await initialize();
    await _channel.invokeMethod<void>('remove', {'regionId': regionId});
  }

  Future<List<String>> regions() async {
    await initialize();
    final value = await _channel.invokeListMethod<String>('regions');
    if (value == null) {
      throw const FormatException('Missing offline map region list');
    }
    return List.unmodifiable(value);
  }
}

final class _OfflineDownloadOperation {
  bool cancelled = false;
}

class OfflineMapDownload {
  const OfflineMapDownload({
    required this.regionId,
    required this.styleUri,
    required this.styleBytes,
    required this.tileBytes,
  });

  factory OfflineMapDownload.fromNative(Map<String, Object?>? value) {
    final region = value?['regionId'];
    final style = value?['styleUri'];
    final styleBytes = value?['styleBytes'];
    final tileBytes = value?['tileBytes'];
    if (region is! String ||
        region.isEmpty ||
        style is! String ||
        style.isEmpty ||
        styleBytes is! int ||
        styleBytes < 0 ||
        tileBytes is! int ||
        tileBytes <= 0) {
      throw const FormatException('Invalid offline map resources');
    }
    return OfflineMapDownload(
      regionId: region,
      styleUri: style,
      styleBytes: styleBytes,
      tileBytes: tileBytes,
    );
  }

  final String regionId;
  final String styleUri;
  final int styleBytes;
  final int tileBytes;
  int get totalBytes => styleBytes + tileBytes;
}
