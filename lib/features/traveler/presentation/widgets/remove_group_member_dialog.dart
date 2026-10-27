import 'package:flutter/material.dart';

/// Screen #59: Remove Group Member Confirmation dialog (UC-20).
///
/// Actor: Traveler acting as Group Host.
/// Purpose: Obtains explicit confirmation before changing membership to Removed.
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
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove Member'),
        ),
      ],
    );
  }
}
