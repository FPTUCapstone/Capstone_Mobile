import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/in_app_notification_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/in_app_inbox_page.dart';

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
    expect(find.text('No notifications yet.'), findsOneWidget);
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
    expect(find.text('You were removed from Da Nang Weekend.'), findsOneWidget);
    expect(find.text('Open group'), findsNothing);
    await tester.tap(find.byKey(const Key('inbox_mark_read_3')));
    await tester.pump();
    expect(repository.reads, 1);
    expect(find.byKey(const Key('inbox_mark_read_3')), findsNothing);
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
    await tester.tap(find.text('Load more'));
    await tester.pump();
    expect(repository.loads, 2);
    await tester.tap(find.byKey(const Key('inbox_unread_filter')));
    await tester.pump();
    expect(repository.unreadOnly, isTrue);
    expect(find.text('No unread notifications.'), findsOneWidget);
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
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('No notifications yet.'), findsOneWidget);
  });
}
