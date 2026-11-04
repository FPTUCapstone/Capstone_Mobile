import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/shared/widgets/notification_permission_notice.dart';

void main() {
  late _Window window;
  late ValueNotifier<bool> denied;

  setUp(() {
    window = _Window();
    denied = ValueNotifier(true);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NotificationPermissionNotice(denied: denied, window: window),
      ),
    ),
  );

  final notice = find.byKey(const Key('notification-permission-notice'));

  testWidgets('granted shows nothing', (tester) async {
    denied.value = false;
    await pump(tester);

    expect(notice, findsNothing);
  });

  testWidgets('denied explains and opens settings without blocking', (
    tester,
  ) async {
    await pump(tester);
    expect(notice, findsOneWidget);
    expect(find.textContaining('still appear in the app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-permission-settings')));
    await tester.pump();

    expect(window.opens, 1);
  });

  testWidgets('settings that cannot open are reported', (tester) async {
    window.canOpen = false;
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-permission-settings')));
    await tester.pump();

    expect(find.textContaining('could not be opened'), findsOneWidget);
  });

  testWidgets('dismissing keeps it away', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-permission-dismiss')));
    await tester.pump();

    expect(notice, findsNothing);
  });

  testWidgets('granting later removes it', (tester) async {
    await pump(tester);

    denied.value = false;
    await tester.pump();

    expect(notice, findsNothing);
  });
}

final class _Window implements DeviceWindow {
  @override
  Future<void> clearNotifications() async {}

  bool canOpen = true;
  int opens = 0;

  @override
  Future<bool> openNotificationSettings() async {
    opens++;
    return canOpen;
  }

  @override
  Future<void> setSecure(bool secure) async {}
}
