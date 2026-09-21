import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_details_page.dart';

void main() {
  const group = TravelGroup(
    id: 42,
    name: 'Da Nang Group',
    inviteCode: 'HOIAN8KP',
    itineraryId: 10,
  );

  testWidgets('Host sees invitation action and existing code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TravelGroupDetailsPage(groupId: 42, group: group, isHost: true),
      ),
    );

    expect(find.text('You are the Group Host.'), findsOneWidget);
    expect(find.text('Invite code: HOIAN8KP'), findsOneWidget);
    expect(find.text('Invite Members'), findsOneWidget);
  });

  testWidgets('member never sees Host controls even with invite code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TravelGroupDetailsPage(groupId: 42, group: group, isHost: false),
      ),
    );

    expect(find.text('You are a Group Member.'), findsOneWidget);
    expect(find.text('You are the Group Host.'), findsNothing);
    expect(find.textContaining('Invite code:'), findsNothing);
    expect(find.text('Invite Members'), findsNothing);
  });

  testWidgets('unknown membership does not claim Host or allow invitations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TravelGroupDetailsPage(groupId: 42)),
    );

    expect(find.text('You are the Group Host.'), findsNothing);
    expect(find.text('Invite Members'), findsNothing);
  });

  testWidgets('Host opens correct group invitation and returns to details', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/group/42',
      routes: [
        GoRoute(
          path: '/group/:groupId',
          builder: (_, state) => const TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            isHost: true,
          ),
        ),
        GoRoute(
          path: '/group/:groupId/invitation',
          name: 'invite-group-members',
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Invitation')),
            body: Text('Invitation for ${state.pathParameters['groupId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Invite Members'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation for 42'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Da Nang Group'), findsOneWidget);
    expect(find.text('Invite Members'), findsOneWidget);
  });
}
