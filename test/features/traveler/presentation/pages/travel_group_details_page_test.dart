import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_details_page.dart';

void main() {
  testWidgets('opens the invite members screen for the current travel group', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/group',
      routes: [
        GoRoute(
          path: '/group',
          builder: (_, _) => const TravelGroupDetailsPage(
            groupId: 42,
            group: TravelGroup(id: 42, name: 'Summer Trip'),
          ),
        ),
        GoRoute(
          path: '/group/:groupId/invitation',
          name: 'invite-group-members',
          builder: (_, _) => const Scaffold(body: Text('Invite Members Page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Invite Members'));
    await tester.pumpAndSettle();

    expect(find.text('Invite Members Page'), findsOneWidget);
  });
}
