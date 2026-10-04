import 'package:flutter/material.dart';

/// Screen #59: Remove Group Member Confirmation dialog (UC-20).
///
/// Actor: Traveler acting as Group Host.
/// Purpose: Obtains explicit confirmation before changing membership to Removed.
/// Production status: Truthful fail-closed implementation because Backend
/// currently lacks a member removal endpoint (NO_BACKEND).
final class RemoveGroupMemberDialog extends StatelessWidget {
  const RemoveGroupMemberDialog({
    super.key,
    required this.groupId,
    required this.memberId,
    required this.memberName,
  });

  final int groupId;
  final int memberId;
  final String memberName;

  /// MSG59 locked message template.
  static String confirmationMessage(String name) =>
      'Are you sure you want to remove $name from this group?';

  /// Truthful capability notice explaining why removal cannot be persisted yet.
  static const String serverUnavailableNotice =
      'Member removal is waiting for server support and cannot be completed yet.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      key: const Key('remove_group_member_dialog'),
      icon: Icon(
        Icons.person_remove_outlined,
        color: theme.colorScheme.error,
        size: 28,
      ),
      title: const Text('Remove group member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              confirmationMessage(memberName),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              key: const Key('remove_member_capability_notice'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      serverUnavailableNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          key: const Key('remove_member_cancel_button'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('remove_member_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: const Size(48, 48),
          ),
          onPressed: () {
            // Production Truthfulness: Server mutation does not exist yet.
            // Do NOT mutate local state, do NOT show fake MSG60 success.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                key: Key('remove_member_unavailable_snack'),
                content: Text(serverUnavailableNotice),
              ),
            );
            Navigator.of(context).pop(false);
          },
          child: const Text('Remove Member'),
        ),
      ],
    );
  }
}
