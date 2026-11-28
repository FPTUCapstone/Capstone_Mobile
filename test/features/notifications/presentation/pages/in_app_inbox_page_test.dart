import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/notifications/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_realtime.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_repository.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/pages/in_app_inbox_page.dart';

final class _Repository implements InAppNotificationRepository {
  _Repository({required this.pages, this.failFirst = false, this.pending});

  final List<InAppNotificationPage> pages;
  final bool failFirst;
  final Future<InAppNotificationPage>? pending;
  int reads = 0;
  int loads = 0;
  bool unreadOnly = false;

  @override
  Future<InAppNotificationPage> getInbox({
    bool unreadOnly = false,
    int limit = 20,
    int? beforeId,
  }) async {
    this.unreadOnly = unreadOnly;
    final call = loads++;
    if (failFirst && call == 0) throw StateError('offline');
    if (pending != null) return pending!;
    return pages[failFirst ? call - 1 : call];
  }

  @override
  Future<void> markRead(int notificationId) async {
    reads++;
  }
}

InAppNotification _notice(int id) => InAppNotification(
  id: id,
  type: 'TravelGroupMemberRemoved',
  title: 'Removed from Da Nang Weekend',
  body: 'You were removed from Da Nang Weekend.',
  relatedEntityType: 'TravelGroup',
  relatedEntityId: 42,
  createdAtUtc: DateTime.utc(2026, 10, 27),
  isRead: false,
);

void main() {
  testWidgets('shows loading until inbox arrives', (tester) async {
    final pending = Completer<InAppNotificationPage>();
    final repository = _Repository(pages: [], pending: pending.future);
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);
    final load = cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const InAppInboxPage()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(InAppNotificationPage(items: [], nextBeforeId: null));
    await load;
    await tester.pump();
    expect(find.text('Chưa có thông báo nào.'), findsOneWidget);
  });

  testWidgets('shows notice without group navigation and marks read', (
    tester,
  ) async {
    final repository = _Repository(
      pages: [
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: null),
      ],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const InAppInboxPage()),
      ),
    );

    expect(find.text('Removed from Da Nang Weekend'), findsOneWidget);
    expect(find.byKey(const Key('inbox_unread_dot_3')), findsOneWidget);
    expect(find.text('You were removed from Da Nang Weekend.'), findsOneWidget);
    expect(find.textContaining('.000'), findsNothing);
    expect(find.text('Open group'), findsNothing);
    await tester.tap(find.byKey(const Key('inbox_mark_read_3')));
    await tester.pump();
    expect(repository.reads, 1);
    expect(find.byKey(const Key('inbox_unread_dot_3')), findsNothing);
    expect(find.byKey(const Key('inbox_mark_read_3')), findsNothing);
    expect(find.text('Đã đọc'), findsOneWidget);
  });

  testWidgets('refreshes an empty inbox to discover new notices', (
    tester,
  ) async {
    final repository = _Repository(
      pages: [
        const InAppNotificationPage(items: [], nextBeforeId: null),
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: null),
      ],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const InAppInboxPage()),
      ),
    );

    await tester.drag(
      find.byKey(const Key('inbox_empty')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Removed from Da Nang Weekend'), findsOneWidget);
  });

  testWidgets('loads more and applies unread filter', (tester) async {
    final repository = _Repository(
      pages: [
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: 3),
        InAppNotificationPage(items: [_notice(2)], nextBeforeId: null),
        InAppNotificationPage(items: [], nextBeforeId: null),
      ],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const InAppInboxPage()),
      ),
    );
    await tester.tap(find.text('Tải thêm'));
    await tester.pump();
    expect(repository.loads, 2);
    await tester.tap(find.byKey(const Key('inbox_unread_filter')));
    await tester.pump();
    expect(repository.unreadOnly, isTrue);
    expect(find.text('Không có thông báo chưa đọc.'), findsOneWidget);
  });

  testWidgets('shows load error and recovers on retry', (tester) async {
    final repository = _Repository(
      failFirst: true,
      pages: [InAppNotificationPage(items: [], nextBeforeId: null)],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const InAppInboxPage()),
      ),
    );
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(find.text('Chưa có thông báo nào.'), findsOneWidget);
  });

  testWidgets(
    'refreshes inbox in place when realtime hub emits a change hint',
    (tester) async {
      final repository = _Repository(
        pages: [
          const InAppNotificationPage(items: [], nextBeforeId: null),
          InAppNotificationPage(items: [_notice(9)], nextBeforeId: null),
        ],
      );
      final realtime = _FakeRealtime();
      final cubit = InAppInboxCubit(repository, realtime: realtime);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const InAppInboxPage()),
        ),
      );
      expect(realtime.startCalls, 1);
      expect(find.text('Chưa có thông báo nào.'), findsOneWidget);

      realtime.emitChange();
      await tester.pump();
      await tester.pump();

      expect(find.text('Removed from Da Nang Weekend'), findsOneWidget);
    },
  );

  test('disposes realtime notification client when cubit closes', () async {
    final repository = _Repository(
      pages: [const InAppNotificationPage(items: [], nextBeforeId: null)],
    );
    final realtime = _FakeRealtime();
    final cubit = InAppInboxCubit(repository, realtime: realtime);
    await cubit.load();
    expect(realtime.startCalls, 1);

    await cubit.close();
    expect(realtime.disposeCalls, 1);
  });
}

final class _FakeRealtime implements InAppNotificationRealtime {
  final StreamController<void> _controller = StreamController<void>.broadcast();
  var startCalls = 0;
  var disposeCalls = 0;

  @override
  Stream<void> get changes => _controller.stream;

  void emitChange() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  @override
  Future<void> start() async => startCalls += 1;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _controller.close();
  }
}
