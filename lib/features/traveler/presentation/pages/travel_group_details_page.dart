import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

final class TravelGroupDetailsPage extends StatelessWidget {
  const TravelGroupDetailsPage({
    super.key,
    required this.groupId,
    this.group,
    this.isHost = false,
  });

  final int groupId;
  final TravelGroup? group;
  final bool isHost;

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
        ],
      ),
    );
  }
}
