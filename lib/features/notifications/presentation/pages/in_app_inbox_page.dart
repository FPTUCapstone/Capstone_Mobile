import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/notifications/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_state.dart';

/// In-app notifications for the signed-in workspace.
final class InAppInboxPage extends StatelessWidget {
  const InAppInboxPage({this.destinationFor, super.key});

  final String? Function(InAppNotification item)? destinationFor;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: BlocBuilder<InAppInboxCubit, InAppInboxState>(
      builder: (context, state) {
        final cubit = context.read<InAppInboxCubit>();
        return Column(
          children: [
            SwitchListTile(
              key: const Key('inbox_unread_filter'),
              title: const Text('Unread only'),
              value: state.unreadOnly,
              onChanged: cubit.setUnreadOnly,
            ),
            Expanded(child: _content(context, state, cubit)),
          ],
        );
      },
    ),
  );

  Widget _content(
    BuildContext context,
    InAppInboxState state,
    InAppInboxCubit cubit,
  ) {
    if (state.status == InAppInboxStatus.initial ||
        state.status == InAppInboxStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == InAppInboxStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage ?? 'Unable to load notifications.'),
            TextButton(onPressed: cubit.retry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            key: const Key('inbox_empty'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Text(
                    state.unreadOnly
                        ? 'No unread notifications.'
                        : 'No notifications yet.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        key: const Key('inbox_items'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            state.items.length +
            (state.hasMore || state.pageError != null ? 1 : 0) +
            (state.actionError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            final item = state.items[index];
            final destination = destinationFor?.call(item);
            return _NotificationTile(
              item: item,
              pending: state.markingReadIds.contains(item.id),
              onMarkRead: () => cubit.markRead(item.id),
              onOpen: destination == null
                  ? null
                  : () async {
                      final opened =
                          item.isRead || await cubit.markRead(item.id);
                      if (opened && context.mounted) {
                        await context.push(destination);
                      }
                    },
            );
          }
          if (index == state.items.length && state.actionError != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.actionError!),
            );
          }
          return Center(
            child: state.isLoadingMore
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: state.pageError == null
                        ? cubit.loadMore
                        : cubit.retry,
                    child: Text(
                      state.pageError == null ? 'Load more' : 'Retry',
                    ),
                  ),
          );
        },
      ),
    );
  }
}

final class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.pending,
    required this.onMarkRead,
    required this.onOpen,
  });

  final InAppNotification item;
  final bool pending;
  final VoidCallback onMarkRead;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title ?? 'Notification',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (item.body case final body?) ...[
            const SizedBox(height: 4),
            Text(body),
          ],
          const SizedBox(height: 4),
          Text(
            formatCalendarDateTime(item.createdAtUtc.toLocal()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!item.isRead)
            Text('Unread', style: Theme.of(context).textTheme.labelMedium),
          if (onOpen != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: pending ? null : onOpen,
                child: const Text('Open'),
              ),
            )
          else if (!item.isRead)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('inbox_mark_read_${item.id}'),
                onPressed: pending ? null : onMarkRead,
                child: const Text('Mark as read'),
              ),
            ),
        ],
      ),
    ),
  );
}
