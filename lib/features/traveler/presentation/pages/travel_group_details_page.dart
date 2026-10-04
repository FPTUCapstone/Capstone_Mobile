import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/leave_travel_group_dialog.dart';

/// Screen for viewing travel group details, inviting members, opening members
/// list, and initiating the UC-21 Leave Travel Group flow (Screen #60).
final class TravelGroupDetailsPage extends StatelessWidget {
  const TravelGroupDetailsPage({
    super.key,
    required this.groupId,
    this.group,
    this.isHost = false,
    this.currentUserId,
    this.members,
    this.repository,
  });

  final int groupId;
  final TravelGroup? group;
  final bool isHost;
  final int? currentUserId;
  final List<TravelGroupMember>? members;
  final TravelGroupRepository? repository;

  @override
  Widget build(BuildContext context) {
    final currentGroup = group?.id == groupId ? group : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Group')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            currentGroup?.name ?? 'Travel Group #$groupId',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (currentGroup != null)
            Text(
              isHost ? 'You are the Group Host.' : 'You are a Group Member.',
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pushNamed(
              AppRouteNames.travelGroupMembers,
              pathParameters: {'groupId': groupId.toString()},
              extra: isHost,
            ),
            icon: const Icon(Icons.group_outlined),
            label: const Text('View members'),
          ),
          if (currentGroup != null && isHost) ...[
            if (currentGroup.inviteCode?.isNotEmpty ?? false) ...[
              const SizedBox(height: 24),
              SelectableText('Invite code: ${currentGroup.inviteCode}'),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pushNamed(
                AppRouteNames.inviteGroupMembers,
                pathParameters: {'groupId': groupId.toString()},
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite Members'),
            ),
          ],
          const SizedBox(height: 32),
          // Danger Zone / Group actions: UC-21 Leave Group
          OutlinedButton.icon(
            key: const Key('leave_group_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => LeaveTravelGroupDialog(
                groupId: groupId,
                groupName: currentGroup?.name ?? 'Travel Group #$groupId',
                isHost: isHost,
                currentUserId: currentUserId,
                members: members,
                repository: repository,
              ),
            ),
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Leave Group'),
          ),
        ],
      ),
    );
  }
}
