import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/remove_group_member_dialog.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

/// Read-only UC19 screen for active travel-group members, with UC-20 member
/// removal entry point for the authenticated Group Host (Screen #59).
///
/// Production Security Rule (P2): Host authority is determined STRICTLY by
/// verifying that the authenticated user ID from the session matches the
/// authoritative Host returned by the Backend. If session identity is absent
/// or does not match, host authority fails closed (never relying on route extra).
final class TravelGroupMembersPage extends StatefulWidget {
  const TravelGroupMembersPage({
    super.key,
    required this.groupId,
    this.isHost = false,
    this.currentUserId,
    this.storage,
  });

  final int groupId;
  final bool isHost;
  final int? currentUserId;
  final SecureStorageService? storage;

  @override
  State<TravelGroupMembersPage> createState() => _TravelGroupMembersPageState();
}

final class _TravelGroupMembersPageState extends State<TravelGroupMembersPage> {
  int? _resolvedUserId;

  @override
  void initState() {
    super.initState();
    _resolvedUserId = widget.currentUserId;
    if (_resolvedUserId == null) {
      _resolveUserId();
    }
  }

  Future<void> _resolveUserId() async {
    final userId = await SessionIdentityHelper.getCurrentUserId(widget.storage);
    if (!mounted) return;
    if (userId != null && userId != _resolvedUserId) {
      setState(() {
        _resolvedUserId = userId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group members')),
      body: BlocBuilder<TravelGroupMembersCubit, TravelGroupMembersState>(
        builder: (context, state) => switch (state) {
          TravelGroupMembersInitial() || TravelGroupMembersLoading() =>
            const Center(child: CircularProgressIndicator()),
          TravelGroupMembersSuccess(:final members) => _MembersContent(
            members: members,
            currentUserId: _resolvedUserId,
          ),
          TravelGroupMembersPermissionDenied() => const ErrorView(
            message: 'You do not have permission to view this group’s members.',
          ),
          TravelGroupMembersNotFound() => const ErrorView(
            message: 'This travel group could not be found.',
          ),
          TravelGroupMembersFailure() => ErrorView(
            message: 'We could not load group members. Please try again.',
            onRetry: () => context.read<TravelGroupMembersCubit>().load(
              groupId: widget.groupId,
            ),
          ),
        },
      ),
    );
  }
}

final class _MembersContent extends StatelessWidget {
  const _MembersContent({required this.members, this.currentUserId});

  final TravelGroupMembers members;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (members.members.isEmpty) {
      return const Center(child: Text('There are no active members yet.'));
    }

    // Host authority audit (P2): Authoritative loaded group members define the true Host.
    // If current authenticated user ID is unavailable or does not match loaded Host,
    // FAIL CLOSED (effectiveViewerIsHost = false). Never rely on GoRouter.extra or route flags.
    final authoritativeHost = members.members
        .where((m) => m.isHost)
        .firstOrNull;
    final bool effectiveViewerIsHost =
        currentUserId != null &&
        authoritativeHost != null &&
        authoritativeHost.memberId == currentUserId;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: members.members.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MembersHeader(members: members);
        }
        return _MemberTile(
          member: members.members[index - 1],
          groupId: members.groupId,
          isViewerHost: effectiveViewerIsHost,
          currentUserId: currentUserId,
        );
      },
    );
  }
}

final class _MembersHeader extends StatelessWidget {
  const _MembersHeader({required this.members});

  final TravelGroupMembers members;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          members.groupName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text('Itinerary #${members.itineraryId}'),
        const SizedBox(height: 4),
        Text(
          '${members.memberCount} active member${members.memberCount == 1 ? '' : 's'}',
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

final class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.groupId,
    this.isViewerHost = false,
    this.currentUserId,
  });

  final TravelGroupMember member;
  final int groupId;
  final bool isViewerHost;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
    final isSelf = currentUserId != null && member.memberId == currentUserId;
    // BR-45: Only Group Host may remove members. Group Host cannot remove itself.
    final showRemoveAction = isViewerHost && !member.isHost && !isSelf;

    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          child: avatarUrl == null ? const Icon(Icons.person_outline) : null,
        ),
        title: Text(
          member.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Joined ${_formatDate(member.joinedAtUtc)}\n'
          'Location sharing: ${member.locationSharingEnabled ? 'Enabled' : 'Disabled'}',
        ),
        trailing: member.isHost
            ? const Chip(
                avatar: Icon(Icons.star_outline, size: 18),
                label: Text('Group Host'),
              )
            : showRemoveAction
            ? TextButton(
                key: Key('remove_member_button_${member.memberId}'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => RemoveGroupMemberDialog(
                    groupId: groupId,
                    memberId: member.memberId,
                    memberName: member.displayName,
                  ),
                ),
                child: const Text('Remove'),
              )
            : null,
      ),
    );
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
