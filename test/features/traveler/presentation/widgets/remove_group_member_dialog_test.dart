import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/remove_group_member_dialog.dart';

void main() {
  group('RemoveGroupMemberDialog (UC-20 Screen #59)', () {
    testWidgets(
      'UC20-4: Renders MSG59 confirmation, dialog title, and capability notice',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RemoveGroupMemberDialog(
                groupId: 42,
                memberId: 102,
                memberName: 'Minh Anh',
              ),
            ),
          ),
        );

        // Dialog title
        expect(find.text('Remove group member'), findsOneWidget);

        // Locked MSG59 body text
        expect(
          find.text(
            'Are you sure you want to remove Minh Anh from this group?',
          ),
          findsOneWidget,
        );

        // Capability notice explaining server support is pending
        expect(
          find.byKey(const Key('remove_member_capability_notice')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Member removal is waiting for server support and cannot be completed yet.',
          ),
          findsOneWidget,
        );

        // Buttons
        expect(
          find.byKey(const Key('remove_member_cancel_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('remove_member_confirm_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'UC20-5: Cancel button dismisses dialog and returns false (no changes)',
      (tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (_) => const RemoveGroupMemberDialog(
                        groupId: 42,
                        memberId: 102,
                        memberName: 'Minh Anh',
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Remove group member'), findsOneWidget);

        await tester.tap(find.byKey(const Key('remove_member_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.text('Remove group member'), findsNothing);
        expect(dialogResult, isFalse);
      },
    );

    testWidgets(
      'UC20-6, UC20-7: Confirm action surfaces unavailable notice and does not report fake success',
      (tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (_) => const RemoveGroupMemberDialog(
                        groupId: 42,
                        memberId: 102,
                        memberName: 'Minh Anh',
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap destructive action
        await tester.tap(find.byKey(const Key('remove_member_confirm_button')));
        await tester.pumpAndSettle();

        // Dialog closes with false
        expect(dialogResult, isFalse);

        // SnackBar surfaces server unavailable notice
        expect(
          find.byKey(const Key('remove_member_unavailable_snack')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Member removal is waiting for server support and cannot be completed yet.',
          ),
          findsOneWidget,
        );

        // Absolutely NO fake MSG60 success
        expect(
          find.textContaining('has been removed from the group.'),
          findsNothing,
        );
      },
    );

    testWidgets('Meets accessibility touch target requirements (>= 48dp)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RemoveGroupMemberDialog(
              groupId: 42,
              memberId: 102,
              memberName: 'Minh Anh',
            ),
          ),
        ),
      );

      final cancelBox = tester.getRect(
        find.byKey(const Key('remove_member_cancel_button')),
      );
      expect(cancelBox.height, greaterThanOrEqualTo(48.0));

      final confirmBox = tester.getRect(
        find.byKey(const Key('remove_member_confirm_button')),
      );
      expect(confirmBox.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'Renders without overflow on small screens and with 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const Scaffold(
                body: RemoveGroupMemberDialog(
                  groupId: 42,
                  memberId: 102,
                  memberName:
                      'A very long member name that wraps multiple lines in confirmation',
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('remove_member_confirm_button')),
          findsOneWidget,
        );
      },
    );
  });
}
