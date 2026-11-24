import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_map_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tripmate.trip_mate_mobile/offline_map');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => null,
            'download' || 'verify' => <String, Object?>{
              'regionId': 'generation-1',
              'styleUri': 'mapbox://styles/mapbox/streets-v12',
              'styleBytes': 1000,
              'tileBytes': 2000,
            },
            'cancel' || 'remove' => null,
            _ => throw MissingPluginException(),
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'uses actual native style and tile bytes and approved descriptor',
    () async {
      final source = OfflineMapDataSource(channel: channel);
      final result = await source.download(
        regionId: 'generation-1',
        geometry: const {'type': 'Polygon', 'coordinates': <Object>[]},
        maxBytes: 150000000,
      );
      expect(result.totalBytes, 3000);
      expect(calls.map((call) => call.method), ['initialize', 'download']);
      final arguments = calls.last.arguments as Map;
      expect(arguments['minZoom'], 10);
      expect(arguments['maxZoom'], 16);
      expect(arguments['maxBytes'], 150000000);
    },
  );

  test(
    'estimate reports known map bytes and does not fabricate missing size',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'estimate') return 1234;
            return null;
          });
      final source = OfflineMapDataSource(channel: channel);
      expect(
        await source.estimate(regionId: 'estimate-1', geometry: const {}),
        1234,
      );
      expect(calls.last.method, 'estimate');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      expect(
        await source.estimate(regionId: 'estimate-2', geometry: const {}),
        isNull,
      );
    },
  );

  test(
    'lists native region identifiers for reference-safe orphan recovery',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'regions') {
              return ['managed-generation', 'foreign-generation'];
            }
            return null;
          });
      final source = OfflineMapDataSource(channel: channel);
      expect(await source.regions(), [
        'managed-generation',
        'foreign-generation',
      ]);
      expect(calls.last.method, 'regions');
    },
  );

  test('cancellation and removal await native operations', () async {
    final source = OfflineMapDataSource(channel: channel);
    await source.cancel();
    await source.remove('generation-1');
    expect(calls.map((call) => call.method), [
      'cancel',
      'initialize',
      'remove',
    ]);
    expect(calls.last.arguments, {'regionId': 'generation-1'});
  });

  test('cancel during initialization never starts a native download', () async {
    final initialized = Completer<void>();
    final entered = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') {
            entered.complete();
            await initialized.future;
          }
          if (call.method == 'download') {
            return {
              'regionId': 'generation-1',
              'styleUri': 'style',
              'styleBytes': 1,
              'tileBytes': 2,
            };
          }
          return null;
        });
    final source = OfflineMapDataSource(channel: channel);
    final download = source.download(
      regionId: 'generation-1',
      geometry: const {},
      maxBytes: 100,
    );
    final cancelled = expectLater(
      download,
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'cancelled',
        ),
      ),
    );
    await entered.future;
    await source.cancel();
    initialized.complete();
    await cancelled;
    expect(calls.where((call) => call.method == 'download'), isEmpty);
  });

  test(
    'late native success cannot report a cancelled operation as downloaded',
    () async {
      final native = Completer<Map<String, Object?>>();
      final entered = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'download') {
              entered.complete();
              return native.future;
            }
            return null;
          });
      final source = OfflineMapDataSource(channel: channel);
      final download = source.download(
        regionId: 'generation-1',
        geometry: const {},
        maxBytes: 100,
      );
      final cancelled = expectLater(
        download,
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'cancelled',
          ),
        ),
      );
      await entered.future;
      await source.cancel();
      native.complete({
        'regionId': 'generation-1',
        'styleUri': 'style',
        'styleBytes': 1,
        'tileBytes': 2,
      });
      await cancelled;
      expect(calls.where((call) => call.method == 'remove').single.arguments, {
        'regionId': 'generation-1',
      });
    },
  );

  test('does not accept incomplete or invalid native verification', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return null;
          return {'regionId': 'generation-1', 'styleBytes': -1, 'tileBytes': 0};
        });
    final source = OfflineMapDataSource(channel: channel);
    await expectLater(source.verify('generation-1'), throwsFormatException);
  });

  test(
    'native failures remain failures instead of successful empty maps',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return null;
            throw PlatformException(code: 'incomplete');
          });
      final source = OfflineMapDataSource(channel: channel);
      await expectLater(
        source.verify('generation-1'),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
