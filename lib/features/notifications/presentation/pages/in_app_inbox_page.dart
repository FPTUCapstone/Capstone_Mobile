import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/notifications/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_state.dart';
import 'package:trip_mate_mobile/features/notifications/resources/in_app_inbox_vi.dart';

/// In-app notifications for the signed-in workspace.
final class InAppInboxPage extends StatelessWidget {
  const InAppInboxPage({this.destinationFor, super.key});

  final String? Function(InAppNotification item)? destinationFor;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text(InAppInboxStringsVi.title),
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
        final unreadCount = state.items.where((item) => !item.isRead).length;
        return Column(
          children: [
            Material(
              color: AppColors.cardBackground,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _InboxTabButton(
                          key: const Key('inbox_all_filter'),
                          label: InAppInboxStringsVi.tabAll,
                          selected: !state.unreadOnly,
                          onTap: () => cubit.setUnreadOnly(false),
                        ),
                        const SizedBox(width: 24),
                        _InboxTabButton(
                          key: const Key('inbox_unread_filter'),
                          label: InAppInboxStringsVi.tabUnreadWithCount(
                            unreadCount,
                          ),
                          selected: state.unreadOnly,
                          onTap: () => cubit.setUnreadOnly(true),
                        ),
                      ],
                    ),
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
                state.errorMessage ?? InAppInboxStringsVi.loadFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: cubit.retry,
                child: const Text(InAppInboxStringsVi.retry),
              ),
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
                              ? InAppInboxStringsVi.emptyUnread
                              : InAppInboxStringsVi.emptyAll,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                        state.pageError == null
                            ? InAppInboxStringsVi.loadMore
                            : InAppInboxStringsVi.retry,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

final class _InboxTabButton extends StatelessWidget {
  const _InboxTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
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
      color: unread ? AppColors.cardBackground : const Color(0xFFFCFBF8),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.38)
              : AppColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  Container(
                    key: Key('inbox_unread_dot_${item.id}'),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.title ?? InAppInboxStringsVi.fallbackItemTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
            if (item.body case final body?) ...[
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEFF1EE)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatInboxDateTime(item.createdAtUtc.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6D807B),
                    ),
                  ),
                ),
                if (onOpen != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: pending ? null : onOpen,
                    child: const Text(
                      InAppInboxStringsVi.openAction,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (unread)
                  TextButton(
                    key: Key('inbox_mark_read_${item.id}'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: pending ? null : onMarkRead,
                    child: const Text(
                      InAppInboxStringsVi.markAsRead,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Text(
                    InAppInboxStringsVi.readLabel,
                    style: TextStyle(fontSize: 12, color: Color(0xFF8DA09A)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatInboxDateTime(DateTime local) {
  final date = formatCalendarDate(local);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$date · $hh:$mm';
}
