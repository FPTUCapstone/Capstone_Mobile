import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

/// Read-only UC19 screen for active travel-group members.
final class TravelGroupMembersPage extends StatelessWidget {
  const TravelGroupMembersPage({super.key, required this.groupId});

  final int groupId;

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
          ),
          TravelGroupMembersPermissionDenied() => const ErrorView(
            message: 'You do not have permission to view this group’s members.',
          ),
          TravelGroupMembersNotFound() => const ErrorView(
            message: 'This travel group could not be found.',
          ),
          TravelGroupMembersFailure() => ErrorView(
            message: 'We could not load group members. Please try again.',
            onRetry: () =>
                context.read<TravelGroupMembersCubit>().load(groupId: groupId),
          ),
        },
      ),
    );
  }
}

final class _MembersContent extends StatelessWidget {
  const _MembersContent({required this.members});

  final TravelGroupMembers members;

  @override
  Widget build(BuildContext context) {
    if (members.members.isEmpty) {
      return const Center(child: Text('There are no active members yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: members.members.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MembersHeader(members: members);
        }
        return _MemberTile(member: members.members[index - 1]);
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
  const _MemberTile({required this.member});

  final TravelGroupMember member;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
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
            ? Chip(
                avatar: const Icon(Icons.star_outline, size: 18),
                label: const Text('Group Host'),
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
