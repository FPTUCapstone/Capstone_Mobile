import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/widgets/chat_composer_sheet.dart';

void main() {
  testWidgets('requires valid VND and a real account before submitting split', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposerSheet(
            kind: GroupComposerKind.splitBill,
            participants: const [
              (userId: 41, displayName: 'Host'),
              (userId: 57, displayName: 'Member'),
            ],
            senderName: 'Host',
            onSubmit: (_, _, _) async {
              calls++;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('chat_tool_title')), 'Lunch');
    await tester.enterText(find.byKey(const Key('chat_expense_amount')), '-1');
    await tester.ensureVisible(find.byKey(const Key('chat_tool_save')));
    await tester.tap(find.byKey(const Key('chat_tool_save')));
    await tester.pump();
    expect(calls, 0);
    expect(find.textContaining('nguyên dương'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('chat_expense_amount')),
      '100001',
    );
    await tester.ensureVisible(find.byKey(const Key('chat_tool_save')));
    await tester.tap(find.byKey(const Key('chat_tool_save')));
    await tester.pump();
    expect(calls, 0);
    expect(find.textContaining('6 đến 30'), findsOneWidget);
  });
  testWidgets(
    'saves exact whole VND shares for actual members and retains form on failure',
    (tester) async {
      Map<String, Object?>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposerSheet(
              kind: GroupComposerKind.splitBill,
              participants: const [
                (userId: 57, displayName: 'Member'),
                (userId: 41, displayName: 'Host'),
              ],
              senderName: 'Host',
              onSubmit: (_, _, metadata) async {
                saved = metadata;
                return 'Máy chủ tạm lỗi. Vui lòng thử lại.';
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('chat_tool_title')), 'Lunch');
      await tester.enterText(
        find.byKey(const Key('chat_expense_amount')),
        '100001',
      );
      await tester.enterText(
        find.byKey(const Key('chat_expense_account')),
        '123456789',
      );
      await tester.ensureVisible(find.byKey(const Key('chat_tool_save')));
      await tester.tap(find.byKey(const Key('chat_tool_save')));
      await tester.pumpAndSettle();
      expect(saved?['totalAmount'], 100001);
      expect(saved?['participants'], [
        {'userId': 41, 'displayName': 'Host', 'amount': 50001},
        {'userId': 57, 'displayName': 'Member', 'amount': 50000},
      ]);
      expect(find.text('Máy chủ tạm lỗi. Vui lòng thử lại.'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
    },
  );
}
