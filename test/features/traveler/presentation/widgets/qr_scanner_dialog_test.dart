import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/qr_scanner_dialog.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

void main() {
  group('QrScannerDialog Acceptance Tests (UC-23 [P2][V02][C02])', () {
    testWidgets(
      'camera permission granted -> QR decoded -> returns parsed code',
      (tester) async {
        String? scannedCode;
        late ValueChanged<String> detectCallback;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QrScannerDialog(
                initialPermission: CameraPermissionState.granted,
                scannerBuilder:
                    (
                      context, {
                      required onDetect,
                      required onPermissionDenied,
                    }) {
                      detectCallback = onDetect;
                      return const Text('Mock Camera Preview');
                    },
                onScanned: (code) => scannedCode = code,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('camera_scanner_view')), findsOneWidget);
        expect(find.text('Mock Camera Preview'), findsOneWidget);
        expect(
          find.byKey(const Key('camera_permission_denied_view')),
          findsNothing,
        );

        // Simulate camera scanning valid QR payload
        detectCallback('tripmate://groups/join?code=DANANG24');
        await tester.pumpAndSettle();

        expect(scannedCode, 'DANANG24');
      },
    );

    testWidgets('permission denied -> MSG46 -> manual code remains usable', (
      tester,
    ) async {
      String? scannedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrScannerDialog(
              initialPermission: CameraPermissionState.denied,
              onScanned: (code) => scannedCode = code,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify MSG46 is displayed
      expect(
        find.byKey(const Key('camera_permission_denied_view')),
        findsOneWidget,
      );
      expect(find.text(QrScannerDialog.msg46), findsOneWidget);
      expect(find.byKey(const Key('camera_scanner_view')), findsNothing);

      // 2. Verify manual code entry is present and usable
      expect(find.byKey(const Key('manual_qr_input_field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('manual_qr_input_field')),
        'HOIAN8KP',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Redeem'));
      await tester.pumpAndSettle();

      expect(scannedCode, 'HOIAN8KP');
    });

    testWidgets(
      'permission runtime denial -> MSG46 -> manual code remains usable',
      (tester) async {
        String? scannedCode;
        late VoidCallback denyCallback;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QrScannerDialog(
                initialPermission: CameraPermissionState.undetermined,
                scannerBuilder:
                    (
                      context, {
                      required onDetect,
                      required onPermissionDenied,
                    }) {
                      denyCallback = onPermissionDenied;
                      return const Text('Camera initializing');
                    },
                onScanned: (code) => scannedCode = code,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Simulate permission denied during initialization
        denyCallback();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('camera_permission_denied_view')),
          findsOneWidget,
        );
        expect(find.text(QrScannerDialog.msg46), findsOneWidget);

        // Redeem via manual field
        await tester.enterText(
          find.byKey(const Key('manual_qr_input_field')),
          'tripmate://groups/join?code=DALAT999',
        );
        await tester.tap(find.widgetWithText(AppButton, 'Redeem'));
        await tester.pumpAndSettle();

        expect(scannedCode, 'DALAT999');
      },
    );

    testWidgets('malformed or unsupported QR -> MSG56 displayed', (
      tester,
    ) async {
      String? scannedCode;
      late ValueChanged<String> detectCallback;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrScannerDialog(
              initialPermission: CameraPermissionState.granted,
              scannerBuilder:
                  (context, {required onDetect, required onPermissionDenied}) {
                    detectCallback = onDetect;
                    return const Text('Mock Camera Preview');
                  },
              onScanned: (code) => scannedCode = code,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate malformed QR detected
      detectCallback('https://randomwebsite.com/invalid-code');
      await tester.pumpAndSettle();

      expect(find.text(QrScannerDialog.msg56), findsOneWidget);
      expect(scannedCode, isNull);
    });

    testWidgets('manual redeem with malformed payload -> MSG56 displayed', (
      tester,
    ) async {
      String? scannedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrScannerDialog(
              initialPermission: CameraPermissionState.denied,
              onScanned: (code) => scannedCode = code,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('manual_qr_input_field')),
        'https://malformed-url.com',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Redeem'));
      await tester.pumpAndSettle();

      expect(find.text(QrScannerDialog.msg56), findsOneWidget);
      expect(scannedCode, isNull);
    });
  });
}
