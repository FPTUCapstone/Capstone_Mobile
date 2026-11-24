import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_map_data_source.dart';

const _token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
const _defaultPhase = String.fromEnvironment(
  'UC16_MAP_PHASE',
  defaultValue: 'bridge',
);
const _region = 'uc16-native-smoke-v1';
// Approximately 1 km around the Da Nang sample center. This is test data,
// never a replacement for the complete itinerary-derived production geometry.
const _geometry = <String, Object?>{
  'type': 'Polygon',
  'coordinates': [
    [
      [108.2106, 16.0384],
      [108.2294, 16.0384],
      [108.2294, 16.0564],
      [108.2106, 16.0564],
      [108.2106, 16.0384],
    ],
  ],
};

Future<void> _configureToken() async {
  expect(_token.startsWith('pk.'), isTrue, reason: 'Public token required');
  MapboxOptions.setAccessToken(_token);
  // The public setter is void but dispatches a native call. Await the getter
  // on the same platform interface before the app-owned bridge creates SDK work.
  await MapboxOptions.accessToken;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Host-only evidence control. Reuse the same installed APK for a genuine
  // process restart without reinstalling or deleting the downloaded region.
  final phaseFile = File('${Directory.systemTemp.path}/uc16-test-phase');
  final requestedPhase = phaseFile.existsSync()
      ? phaseFile.readAsStringSync().trim()
      : _defaultPhase;
  const phases = {'bridge', 'download', 'verify-offline', 'shared', 'cancel'};
  final phase = phases.contains(requestedPhase)
      ? requestedPhase
      : _defaultPhase;
  final resultFile = File(
    '${Directory.systemTemp.path}/uc16-test-result-$phase.json',
  );
  resultFile.writeAsStringSync(
    jsonEncode({'phase': phase, 'successful': false}),
    flush: true,
  );
  debugPrint('UC16_PHASE_STARTED phase=$phase');
  tearDownAll(() async {
    final successful = binding.failureMethodsDetails.isEmpty;
    final details =
        jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
    await resultFile.writeAsString(
      jsonEncode({...details, 'phase': phase, 'successful': successful}),
      flush: true,
    );
    debugPrint('UC16_PHASE_FINISHED phase=$phase successful=$successful');
  });
  final source = OfflineMapDataSource();

  testWidgets('Android bridge uses no-backup storage and real SDK errors', (
    tester,
  ) async {
    if (_token.startsWith('pk.')) {
      await _configureToken();
    }
    await source.initialize();
    final storage = await source.storage();
    expect(storage['path'], contains('no_backup'));
    expect(storage['freeBytes'], isA<int>());
    expect(storage['freeBytes'] as int, greaterThan(0));
    await source.cancel();
    await expectLater(
      source.verify('uc16-does-not-exist'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'incomplete',
        ),
      ),
    );
  });

  testWidgets(
    'downloads actual Mapbox style and zoom10–16 region',
    (tester) async {
      expect(_token.startsWith('pk.'), isTrue, reason: 'Public token required');
      await _configureToken();
      await source.remove(_region);
      final estimate = await source.estimate(
        regionId: 'uc16-estimate-smoke',
        geometry: _geometry,
      );
      expect(estimate == null || estimate >= 0, isTrue);
      final result = await source.download(
        regionId: _region,
        geometry: _geometry,
        maxBytes: 150000000,
      );
      expect(result.tileBytes, greaterThan(0));
      expect(result.styleBytes, greaterThan(0));
      expect(result.totalBytes, lessThanOrEqualTo(150000000));
      debugPrint(
        'UC16_NATIVE_BYTES style=${result.styleBytes} tiles=${result.tileBytes} total=${result.totalBytes}',
      );
      final persisted = await source.verify(_region);
      expect(persisted.totalBytes, result.totalBytes);
      // Deliberately retain the region for the separate process-restart phase.
    },
    skip: phase != 'download',
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'retained region renders after process restart with network disabled',
    (tester) async {
      expect(_token.startsWith('pk.'), isTrue, reason: 'Public token required');
      await _configureToken();
      final result = await source.verify(_region);
      expect(result.totalBytes, greaterThan(0));
      final loaded = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapWidget(
              styleUri: result.styleUri,
              viewport: CameraViewportState(
                center: Point(coordinates: Position(108.22, 16.0474)),
                zoom: 16,
              ),
              onMapLoadedListener: (_) {
                if (!loaded.isCompleted) loaded.complete();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await loaded.future.timeout(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      debugPrint('UC16_OFFLINE_RENDER_READY');
      // Persist before reporter shutdown so a raw Activity launch remains
      // inspectable even without a host Flutter test driver attached.
      await resultFile.writeAsString(
        jsonEncode({
          'phase': phase,
          'successful': binding.failureMethodsDetails.isEmpty,
          'mapLoaded': true,
          'regionId': result.regionId,
          'resourceBytes': result.totalBytes,
        }),
        flush: true,
      );
      // Give the host evidence harness time to capture the actual native map.
      await Future<void>.delayed(const Duration(seconds: 5));
      // Run only after adb airplane-mode/force-stop; this test cannot claim
      // offline evidence if the harness did not disable networking externally.
    },
    skip: phase != 'verify-offline',
  );

  testWidgets(
    'existing region survives immediate native preflight cancellation',
    (tester) async {
      await _configureToken();
      await source.verify(_region);
      const channel = MethodChannel(OfflineMapDataSource.channelName);
      final duplicate = channel.invokeMethod<Object?>('download', {
        'regionId': _region,
        'geometry': _geometry,
        'maxBytes': 150000000,
      });
      final failed = expectLater(duplicate, throwsA(isA<PlatformException>()));
      await channel.invokeMethod<void>('cancel');
      await failed;
      expect((await source.verify(_region)).totalBytes, greaterThan(0));
    },
    skip: phase != 'shared' && phase != 'download',
  );

  testWidgets(
    'removing one generation preserves another generation shared style',
    (tester) async {
      await _configureToken();
      const first = 'uc16-shared-a-v1';
      const second = 'uc16-shared-b-v1';
      await source.remove(first);
      await source.remove(second);
      await source.download(
        regionId: first,
        geometry: _geometry,
        maxBytes: 150000000,
      );
      await source.download(
        regionId: second,
        geometry: _geometry,
        maxBytes: 150000000,
      );
      await source.remove(first);
      expect((await source.verify(second)).totalBytes, greaterThan(0));
      await source.remove(second);
      // The original smoke region is still available for inspection.
      expect((await source.verify(_region)).totalBytes, greaterThan(0));
    },
    skip: phase != 'shared' && phase != 'download',
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'cancel stops native work and never publishes a complete region',
    (tester) async {
      expect(_token.startsWith('pk.'), isTrue, reason: 'Public token required');
      await _configureToken();
      const id = 'uc16-cancellation-smoke-v1';
      await source.remove(id);
      final started = Completer<void>();
      final download = source.download(
        regionId: id,
        geometry: _geometry,
        maxBytes: 150000000,
        onProgress: (_, _, _) {
          if (!started.isCompleted) started.complete();
        },
      );
      // Attach the error observer before cancellation emits its native error.
      final failed = expectLater(download, throwsA(anything));
      await started.future.timeout(const Duration(seconds: 45));
      await source.cancel();
      await failed;
      await expectLater(source.verify(id), throwsA(anything));
    },
    skip: phase != 'cancel' && phase != 'download',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
