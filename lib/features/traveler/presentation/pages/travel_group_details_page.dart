import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

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
          const SizedBox(height: 24),
          AppButton(
            label: 'Invite Members',
            onPressed: () => context.goNamed(
              AppRouteNames.inviteGroupMembers,
              pathParameters: {'groupId': groupId.toString()},
            ),
          ),
        ],
      ),
    );
  }
}
