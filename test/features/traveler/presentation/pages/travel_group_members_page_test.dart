import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_members_page.dart';

void main() {
  testWidgets('renders host badge and fallback avatar for a long member name', (
    tester,
  ) async {
    final cubit = TravelGroupMembersCubit(repository: _NeverCalledRepository());
    cubit.emitForTest(
      TravelGroupMembersSuccess(
        TravelGroupMembers(
          groupId: 42,
          groupName: 'Da Nang Weekend',
          itineraryId: 10,
          members: [
            TravelGroupMember(
              memberId: 101,
              displayName:
                  'A very long traveler name that must remain readable',
              isHost: true,
              joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
              locationSharingEnabled: false,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TravelGroupMembersPage(groupId: 42),
        ),
      ),
    );

    expect(find.text('Group Host'), findsOneWidget);
    expect(find.text('Itinerary #10'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.textContaining('A very long traveler name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _NeverCalledRepository implements TravelGroupRepository {
  @override
  Future<TravelGroupMembers> getTravelGroupMembers({required int groupId}) =>
      throw UnimplementedError();

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

extension on TravelGroupMembersCubit {
  void emitForTest(TravelGroupMembersState state) => emit(state);
}
