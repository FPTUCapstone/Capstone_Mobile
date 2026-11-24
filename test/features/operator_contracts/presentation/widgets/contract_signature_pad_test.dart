import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/widgets/contract_signature_pad.dart';

void main() {
  Widget subject(ValueChanged<Uint8List?> onChanged, {bool disabled = false}) =>
      MaterialApp(
        home: Scaffold(
          body: ContractSignaturePad(onChanged: onChanged, disabled: disabled),
        ),
      );

  testWidgets('a tap cannot produce a valid drawn signature', (tester) async {
    final emitted = <Uint8List?>[];
    await tester.pumpWidget(subject(emitted.add));
    await tester.tap(find.byKey(ContractSignaturePad.drawingSurfaceKey));
    await tester.pump();
    expect(emitted.whereType<Uint8List>(), isEmpty);
  });

  testWidgets(
    'completed strokes export PNG bytes with transparent background',
    (tester) async {
      final exported = Completer<Uint8List>();
      await tester.pumpWidget(
        subject((bytes) {
          if (bytes != null && !exported.isCompleted) exported.complete(bytes);
        }),
      );
      final origin = tester.getCenter(
        find.byKey(ContractSignaturePad.drawingSurfaceKey),
      );
      final gesture = await tester.startGesture(origin);
      await gesture.moveBy(const Offset(30, -15));
      await gesture.moveBy(const Offset(30, 25));
      await gesture.moveBy(const Offset(30, -10));
      await gesture.up();
      for (var attempt = 0; attempt < 50 && !exported.isCompleted; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(exported.isCompleted, isTrue);
      await tester.runAsync(() async {
        final bytes = await exported.future.timeout(const Duration(seconds: 5));
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await decodeImageFromList(bytes);
        expect(codec.width, 600);
        expect(codec.height, 200);
        final pixels = await codec.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(pixels!.getUint8(3), 0);
        codec.dispose();
      });
      await tester.pump();
    },
  );

  testWidgets('clear invalidates a pending export and leaves no signature', (
    tester,
  ) async {
    final emitted = <Uint8List?>[];
    await tester.pumpWidget(subject(emitted.add));
    final origin = tester.getCenter(
      find.byKey(ContractSignaturePad.drawingSurfaceKey),
    );
    final gesture = await tester.startGesture(origin);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 20));
    await tester.pump();
    await gesture.up();
    // Clear synchronously before the native PNG conversion can complete.
    tester
        .widget<TextButton>(find.byKey(ContractSignaturePad.clearButtonKey))
        .onPressed!();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(emitted, isNotEmpty);
    expect(emitted.last, isNull);
    expect(emitted.whereType<Uint8List>(), isEmpty);
  });

  testWidgets('disabled pad ignores drawing and disables clear', (
    tester,
  ) async {
    final emitted = <Uint8List?>[];
    await tester.pumpWidget(subject(emitted.add, disabled: true));
    await tester.drag(
      find.byKey(ContractSignaturePad.drawingSurfaceKey),
      const Offset(120, 30),
    );
    await tester.pump();
    expect(emitted, isEmpty);
    expect(
      tester
          .widget<TextButton>(find.byKey(ContractSignaturePad.clearButtonKey))
          .onPressed,
      isNull,
    );
  });

  testWidgets('cancelled first stroke never becomes a valid signature', (
    tester,
  ) async {
    final emitted = <Uint8List?>[];
    await tester.pumpWidget(subject(emitted.add));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ContractSignaturePad.drawingSurfaceKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 20));
    await gesture.cancel();
    await tester.pump();
    expect(emitted.whereType<Uint8List>(), isEmpty);
  });

  testWidgets('unmount invalidates a pending PNG export without callbacks', (
    tester,
  ) async {
    final emitted = <Uint8List?>[];
    await tester.pumpWidget(subject(emitted.add));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ContractSignaturePad.drawingSurfaceKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 20));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(emitted.whereType<Uint8List>(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
