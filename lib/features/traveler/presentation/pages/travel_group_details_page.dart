import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

final class TravelGroupDetailsPage extends StatelessWidget {
  const TravelGroupDetailsPage({super.key, required this.groupId, this.group});

  final int groupId;
  final TravelGroup? group;

  @override
  Widget build(BuildContext context) {
    final currentGroup = group;
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
          const Text('You are the Group Host.'),
          if (currentGroup != null) ...[
            const SizedBox(height: 24),
            SelectableText('Invite code: ${currentGroup.inviteCode}'),
          ],
        ],
      ),
    );
  }
}
