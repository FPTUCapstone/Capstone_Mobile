import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/in_app_notification_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_state.dart';

void main() {
  test('loads, paginates, and stops at the last page', () async {
    final repository = _FakeRepository(
      pages: [
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: 3),
        InAppNotificationPage(items: [_notice(2)], nextBeforeId: null),
      ],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadMore();
    await cubit.loadMore();

    expect(cubit.state.status, InAppInboxStatus.ready);
    expect(cubit.state.items.map((item) => item.id), [3, 2]);
    expect(cubit.state.hasMore, isFalse);
    expect(repository.beforeIds, [null, 3]);
  });

  test('unread filter resets the cursor and items', () async {
    final repository = _FakeRepository(
      pages: [
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: 3),
        InAppNotificationPage(items: [_notice(2)], nextBeforeId: null),
      ],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.setUnreadOnly(true);

    expect(repository.unreadFlags, [false, true]);
    expect(repository.beforeIds, [null, null]);
    expect(cubit.state.items.map((item) => item.id), [2]);
  });

  test(
    'read changes only after success and removes from unread view',
    () async {
      final read = Completer<void>();
      final repository = _FakeRepository(
        pages: [
          InAppNotificationPage(items: [_notice(3)], nextBeforeId: null),
        ],
        read: read.future,
      );
      final cubit = InAppInboxCubit(repository);
      addTearDown(cubit.close);
      await cubit.setUnreadOnly(true);

      final pending = cubit.markRead(3);
      expect(cubit.state.items.single.isRead, isFalse);
      read.complete();
      await pending;

      expect(cubit.state.items, isEmpty);
      expect(repository.readIds, [3]);
    },
  );

  test(
    'read failure keeps item and exposes a retryable action error',
    () async {
      final repository = _FakeRepository(
        pages: [
          InAppNotificationPage(items: [_notice(3)], nextBeforeId: null),
        ],
        readError: const NotFoundFailure(),
      );
      final cubit = InAppInboxCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.markRead(3);

      expect(cubit.state.items.single.isRead, isFalse);
      expect(cubit.state.actionError, isNotNull);
    },
  );

  test('load error can be retried without losing filter', () async {
    final repository = _FakeRepository(
      pages: [
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: null),
      ],
      loadError: const NetworkFailure(),
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);

    await cubit.setUnreadOnly(true);
    expect(cubit.state.status, InAppInboxStatus.error);
    repository.loadError = null;
    await cubit.retry();

    expect(cubit.state.status, InAppInboxStatus.ready);
    expect(cubit.state.unreadOnly, isTrue);
    expect(repository.unreadFlags, [true, true]);
  });

  test('paging failure preserves items and cursor for retry', () async {
    final repository = _FakeRepository(
      pages: [
        InAppNotificationPage(items: [_notice(3)], nextBeforeId: 3),
        InAppNotificationPage(items: [_notice(2)], nextBeforeId: null),
      ],
    );
    final cubit = InAppInboxCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    repository.loadError = const NetworkFailure();

    await cubit.loadMore();
    expect(cubit.state.items.map((item) => item.id), [3]);
    expect(cubit.state.nextBeforeId, 3);
    expect(cubit.state.pageError, isNotNull);
    repository.loadError = null;
    await cubit.retry();
    expect(cubit.state.items.map((item) => item.id), [3, 2]);
  });
}

InAppNotification _notice(int id) => InAppNotification(
  id: id,
  type: 'TravelGroupMemberRemoved',
  title: 'Removed',
  body: 'Da Nang Weekend',
  relatedEntityType: 'TravelGroup',
  relatedEntityId: 9,
  createdAtUtc: DateTime.utc(2026, 10, 27),
  isRead: false,
);

final class _FakeRepository implements InAppNotificationRepository {
  _FakeRepository({
    required this.pages,
    this.read,
    this.readError,
    this.loadError,
  });

  final List<InAppNotificationPage> pages;
  final Future<void>? read;
  Object? readError;
  Object? loadError;
  final beforeIds = <int?>[];
  final unreadFlags = <bool>[];
  final readIds = <int>[];

  @override
  Future<InAppNotificationPage> getInbox({
    bool unreadOnly = false,
    int limit = 20,
    int? beforeId,
  }) async {
    unreadFlags.add(unreadOnly);
    beforeIds.add(beforeId);
    if (loadError != null) throw loadError!;
    return pages.removeAt(0);
  }

  @override
  Future<void> markRead(int notificationId) async {
    readIds.add(notificationId);
    if (readError != null) throw readError!;
    if (read != null) await read;
  }
}
