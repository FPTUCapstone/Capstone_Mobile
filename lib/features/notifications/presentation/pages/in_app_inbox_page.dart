import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
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
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Notifications'),
      backgroundColor: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: AppColors.line),
      ),
    ),
    body: BlocBuilder<InAppInboxCubit, InAppInboxState>(
      builder: (context, state) {
        final cubit = context.read<InAppInboxCubit>();
        return Column(
          children: [
            Material(
              color: AppColors.cardBackground,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    key: const Key('inbox_unread_filter'),
                    dense: true,
                    title: const Text(
                      'Unread only',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    activeThumbColor: AppColors.primary,
                    value: state.unreadOnly,
                    onChanged: cubit.setUnreadOnly,
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
                ],
              ),
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 40,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.errorMessage ?? 'Unable to load notifications.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: cubit.retry, child: const Text('Retry')),
            ],
          ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          state.unreadOnly
                              ? 'No unread notifications.'
                              : 'No notifications yet.',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
              child: Text(
                state.actionError!,
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return Card(
      elevation: 0,
      color: unread ? const Color(0xFFF2F7F4) : AppColors.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.title ?? 'Notification',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Unread',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (item.body case final body?) ...[
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.ink,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatCalendarDateTime(item.createdAtUtc.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (onOpen != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: pending ? null : onOpen,
                    child: const Text('Open'),
                  )
                else if (unread)
                  TextButton(
                    key: Key('inbox_mark_read_${item.id}'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: pending ? null : onMarkRead,
                    child: const Text('Mark as read'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
