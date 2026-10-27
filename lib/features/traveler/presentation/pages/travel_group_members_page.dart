import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/remove_group_member_dialog.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

/// Active group member list and UC-20 Host removal flow (Screen #59).
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

  Future<void> _confirmRemoval(TravelGroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => RemoveGroupMemberDialog(
        groupId: widget.groupId,
        memberId: member.memberId,
        memberName: member.displayName,
      ),
    );
    if (!mounted || confirmed != true) return;
    await context.read<TravelGroupMembersCubit>().removeMember(
      groupId: widget.groupId,
      memberUserId: member.memberId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TravelGroupMembersCubit, TravelGroupMembersState>(
      listenWhen: (previous, current) =>
          (current is TravelGroupMembersPermissionDenied &&
              previous is! TravelGroupMembersPermissionDenied) ||
          (current is TravelGroupMembersAuthenticationRequired &&
              previous is! TravelGroupMembersAuthenticationRequired),
      listener: (context, state) {
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go(
            state is TravelGroupMembersAuthenticationRequired
                ? AppRoutes.login
                : AppRoutes.traveler,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Group members')),
        body: BlocBuilder<TravelGroupMembersCubit, TravelGroupMembersState>(
          builder: (context, state) => switch (state) {
            TravelGroupMembersInitial() || TravelGroupMembersLoading() =>
              const Center(child: CircularProgressIndicator()),
            TravelGroupMembersSuccess(:final members) => _MembersContent(
              members: members,
              currentUserId: _resolvedUserId,
              onRemove: _confirmRemoval,
              notice: state.removedMemberName == null
                  ? null
                  : '${state.removedMemberName} has been removed from the group.',
            ),
            TravelGroupMembersRemoving(:final members) => _MembersContent(
              members: members,
              currentUserId: _resolvedUserId,
              notice: 'Removing member...',
            ),
            TravelGroupMembersRemovalRetryable(:final members) =>
              _MembersContent(
                members: members,
                currentUserId: _resolvedUserId,
                notice: 'Unable to confirm removal. Please try again.',
                onRetry: () =>
                    context.read<TravelGroupMembersCubit>().retryRemoval(),
              ),
            TravelGroupMembersRemovalIssue(:final members, :final message) =>
              _MembersContent(
                members: members,
                currentUserId: _resolvedUserId,
                notice: message,
                onRefresh: () => context.read<TravelGroupMembersCubit>().load(
                  groupId: widget.groupId,
                ),
              ),
            TravelGroupMembersPermissionDenied() => const ErrorView(
              message:
                  'You do not have permission to view this group’s members.',
            ),
            TravelGroupMembersAuthenticationRequired() => const ErrorView(
              message: 'Please sign in to continue.',
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
      ),
    );
  }
}

final class _MembersContent extends StatelessWidget {
  const _MembersContent({
    required this.members,
    this.currentUserId,
    this.onRemove,
    this.notice,
    this.onRetry,
    this.onRefresh,
  });

  final TravelGroupMembers members;
  final int? currentUserId;
  final void Function(TravelGroupMember)? onRemove;
  final String? notice;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (members.members.isEmpty) {
      return const Center(child: Text('There are no active members yet.'));
    }

    // Host authority audit (P2): Authoritative loaded group members define the true Host.
    // If current authenticated user ID is unavailable or does not match loaded Host,
    // FAIL CLOSED (effectiveViewerIsHost = false). Never rely on GoRouter.extra or route flags.
    final hosts = members.members.where((m) => m.isHost).toList();
    final bool effectiveViewerIsHost =
        currentUserId != null &&
        hosts.length == 1 &&
        hosts.single.memberId == currentUserId;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: members.members.length + 1 + (notice == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MembersHeader(members: members);
        }
        if (notice != null && index == 1) {
          return Row(
            children: [
              Expanded(child: Text(notice!)),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              if (onRefresh != null)
                TextButton(onPressed: onRefresh, child: const Text('Refresh')),
            ],
          );
        }
        final memberIndex = index - 1 - (notice == null ? 0 : 1);
        return _MemberTile(
          member: members.members[memberIndex],
          isViewerHost: effectiveViewerIsHost,
          currentUserId: currentUserId,
          onRemove: onRemove,
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
    this.isViewerHost = false,
    this.currentUserId,
    this.onRemove,
  });

  final TravelGroupMember member;
  final bool isViewerHost;
  final int? currentUserId;
  final void Function(TravelGroupMember)? onRemove;

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
                onPressed: onRemove == null ? null : () => onRemove!(member),
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
