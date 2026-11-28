import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/widgets/submit_tour_dialog.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/widgets/tour_package_widgets.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(320, 568),
    double scale = 2,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<Object>(
                context: context,
                builder: (_) => const SubmitTourDialog(
                  title: 'Da Nang tour with a long descriptive title',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'small screen with keyboard and large text scrolls without overflow',
    (tester) async {
      await open(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), '  Staff context  ');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Hủy'));
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(SubmitTourDialog), findsNothing);
    },
  );
  testWidgets('overlong UTF16 note stays open and Escape dismisses', (
    tester,
  ) async {
    await open(tester, size: const Size(800, 1000), scale: 1);
    await tester.enterText(find.byType(TextFormField), '\u{1F600}' * 2001);
    await tester.tap(find.text('Gửi duyệt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rút gọn ghi chú gửi duyệt'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SubmitTourDialog), findsNothing);
  });
  test('all readiness blockers and unknown codes use human copy', () {
    expect(
      tourBlockerMessage('required_fields_missing'),
      contains('thông tin tour bắt buộc'),
    );
    expect(
      tourBlockerMessage('itinerary_missing'),
      contains('từng ngày của tour'),
    );
    expect(
      tourBlockerMessage('internal_secret_code'),
      isNot(contains('internal_secret_code')),
    );
  });
}
