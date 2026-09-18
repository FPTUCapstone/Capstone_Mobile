import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

final class TravelGroupDetailsPage extends StatelessWidget {
  const TravelGroupDetailsPage({
    super.key,
    required this.groupId,
    this.group,
    this.isHost,
  });

  final int groupId;
  final TravelGroup? group;
  final bool? isHost;

  @override
  Widget build(BuildContext context) {
    final currentGroup = group;
    final effectiveIsHost =
        isHost ??
        (currentGroup?.inviteCode != null &&
            currentGroup!.inviteCode!.isNotEmpty);

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
          Text(
            effectiveIsHost
                ? 'You are the Group Host.'
                : 'You are a Group Member.',
          ),
          if (effectiveIsHost && currentGroup?.inviteCode != null) ...[
            const SizedBox(height: 24),
            SelectableText('Invite code: ${currentGroup!.inviteCode}'),
          ],
        ],
      ),
    );
  }
}
