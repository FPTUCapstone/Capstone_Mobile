import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';

/// Canonical Screen #60: Leave Travel Group Confirmation dialog (UC-21).
///
/// Supports three distinct business cases according to Report 3 SRS §3.4.5:
///   1. Case A (NON_HOST): Non-host member leaves (MSG130).
///   2. Case B (HOST_WITH_MEMBERS): Group Host leaves while other active
///      members remain. Previews deterministic successor by earliest Joined
///      Timestamp (BR-49, MSG61).
///   3. Case C (FINAL_HOST): Group Host is the final active member.
///      Explains group closure (MSG130).
///
/// Production Status: Truthful fail-closed implementation because Backend
/// currently lacks leave and atomic host succession endpoints (NO_BACKEND).
final class LeaveTravelGroupDialog extends StatefulWidget {
  const LeaveTravelGroupDialog({
    super.key,
    required this.groupId,
    required this.groupName,
    this.isHost = false,
    this.currentUserId,
    this.members,
    this.repository,
  });

  final int groupId;
  final String groupName;
  final bool isHost;
  final int? currentUserId;
  final List<TravelGroupMember>? members;
  final TravelGroupRepository? repository;

  /// MSG61 locked message template.
  static String hostSuccessionMessage(String nextMemberName) =>
      'You are the Group Host. Leaving will transfer Host privileges to $nextMemberName. Confirm leave?';

  /// MSG130 locked message constant.
  static const String confirmationWarningMessage =
      'Are you sure you want to continue? This action may not be reversible.';

  /// Truthful capability notice explaining why leave cannot be persisted yet.
  static const String serverUnavailableNotice =
      'This action is waiting for server support and cannot be completed yet.';

  @override
  State<LeaveTravelGroupDialog> createState() => _LeaveTravelGroupDialogState();
}

final class _LeaveTravelGroupDialogState extends State<LeaveTravelGroupDialog> {
  bool _isLoading = false;
  String? _loadError;
  List<TravelGroupMember>? _resolvedMembers;

  @override
  void initState() {
    super.initState();
    _resolvedMembers = widget.members;
    if (widget.isHost && _resolvedMembers == null) {
      _fetchMembers();
    }
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final repo =
          widget.repository ??
          (serviceLocator.isRegistered<TravelGroupRepository>()
              ? serviceLocator<TravelGroupRepository>()
              : null);

      if (repo == null) {
        setState(() {
          _isLoading = false;
          _loadError =
              'We could not determine group members. Leaving cannot be completed right now.';
        });
        return;
      }

      final result = await repo.getTravelGroupMembers(groupId: widget.groupId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resolvedMembers = result.members;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'We could not determine group members. Leaving cannot be completed right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return AlertDialog(
        key: const Key('leave_group_loading_dialog'),
        content: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking group members...'),
            ],
          ),
        ),
      );
    }

    if (_loadError != null) {
      return AlertDialog(
        key: const Key('leave_group_error_dialog'),
        icon: Icon(Icons.error_outline, color: theme.colorScheme.error),
        title: const Text('Cannot leave group'),
        content: Text(_loadError!),
        actions: [
          TextButton(
            key: const Key('leave_group_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    // Determine Case A, B, or C, or Ambiguous Tie
    if (!widget.isHost) {
      return _buildCaseANonHost(theme);
    }

    final members = _resolvedMembers ?? const <TravelGroupMember>[];
    final eligible = TravelGroupMember.getEligibleSuccessors(
      members,
      currentHostId: widget.currentUserId,
    );

    if (eligible.isEmpty) {
      return _buildCaseCFinalHost(theme);
    }

    if (TravelGroupMember.hasAmbiguousSuccessorTie(
      members,
      currentHostId: widget.currentUserId,
    )) {
      return _buildAmbiguousSuccessor(theme);
    }

    final successor = TravelGroupMember.determineSuccessor(
      members,
      currentHostId: widget.currentUserId,
    );

    if (successor != null) {
      return _buildCaseBHostWithMembers(theme, successor);
    } else {
      return _buildCaseCFinalHost(theme);
    }
  }

  Widget _buildAmbiguousSuccessor(ThemeData theme) {
    return AlertDialog(
      key: const Key('leave_travel_group_dialog_ambiguous'),
      icon: Icon(Icons.help_outline, color: theme.colorScheme.error, size: 28),
      title: const Text('Cannot determine next host'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multiple members share the earliest join timestamp. '
              'Host succession cannot be determined unambiguously without server resolution.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildCapabilityNotice(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('leave_group_cancel_button'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildCaseANonHost(ThemeData theme) {
    return AlertDialog(
      key: const Key('leave_travel_group_dialog_case_a'),
      icon: Icon(
        Icons.exit_to_app_outlined,
        color: theme.colorScheme.error,
        size: 28,
      ),
      title: const Text('Leave travel group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LeaveTravelGroupDialog.confirmationWarningMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildCapabilityNotice(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('leave_group_cancel_button'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('leave_group_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: const Size(48, 48),
          ),
          onPressed: _handleConfirmLeave,
          child: const Text('Leave Group'),
        ),
      ],
    );
  }

  Widget _buildCaseBHostWithMembers(
    ThemeData theme,
    TravelGroupMember successor,
  ) {
    return AlertDialog(
      key: const Key('leave_travel_group_dialog_case_b'),
      icon: Icon(
        Icons.published_with_changes_outlined,
        color: theme.colorScheme.error,
        size: 28,
      ),
      title: const Text('Transfer host privileges and leave'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BR-49 successor preview card
            Container(
              key: const Key('successor_member_card'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: successor.avatarUrl != null
                            ? NetworkImage(successor.avatarUrl!)
                            : null,
                        child: successor.avatarUrl == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              successor.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Joined ${_formatDate(successor.joinedAtUtc)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.star_outline, size: 16),
                    label: const Text('New Host'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              LeaveTravelGroupDialog.hostSuccessionMessage(
                successor.displayName,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildCapabilityNotice(theme),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          key: const Key('leave_group_cancel_button'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('transfer_and_leave_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: const Size(48, 48),
          ),
          onPressed: _handleConfirmLeave,
          child: const Text('Transfer and leave'),
        ),
      ],
    );
  }

  Widget _buildCaseCFinalHost(ThemeData theme) {
    return AlertDialog(
      key: const Key('leave_travel_group_dialog_case_c'),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        size: 28,
      ),
      title: const Text('Close group and leave'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are the final member of this travel group. Leaving will close the group for everyone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              LeaveTravelGroupDialog.confirmationWarningMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildCapabilityNotice(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('leave_group_cancel_button'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('close_group_and_leave_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: const Size(48, 48),
          ),
          onPressed: _handleConfirmLeave,
          child: const Text('Close group and leave'),
        ),
      ],
    );
  }

  Widget _buildCapabilityNotice(ThemeData theme) {
    return Container(
      key: const Key('leave_group_capability_notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              LeaveTravelGroupDialog.serverUnavailableNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConfirmLeave() {
    // Production Truthfulness: Server mutation does not exist yet.
    // Do NOT navigate away, do NOT show fake MSG129 success, do NOT mutate state.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('leave_group_unavailable_snack'),
        content: Text(LeaveTravelGroupDialog.serverUnavailableNotice),
      ),
    );
    Navigator.of(context).pop(false);
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
