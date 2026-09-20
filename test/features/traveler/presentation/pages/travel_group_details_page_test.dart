import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_details_page.dart';

void main() {
  testWidgets('displays Group Host and invite code when user is host', (
    tester,
  ) async {
    const group = TravelGroup(
      id: 42,
      name: 'Da Nang Group',
      inviteCode: 'HOIAN8KP',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TravelGroupDetailsPage(groupId: 42, group: group, isHost: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You are the Group Host.'), findsOneWidget);
    expect(find.text('Invite code: HOIAN8KP'), findsOneWidget);
  });

  testWidgets('displays Group Member without invite code when user is member', (
    tester,
  ) async {
    const group = TravelGroup(id: 42, name: 'Da Nang Group', itineraryId: 10);

    await tester.pumpWidget(
      const MaterialApp(
        home: TravelGroupDetailsPage(groupId: 42, group: group, isHost: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You are a Group Member.'), findsOneWidget);
    expect(find.textContaining('Invite code:'), findsNothing);
  });
}
