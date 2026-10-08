import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_members_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/remove_group_member_dialog.dart';

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

  testWidgets(
    'Host sees Remove button on non-host members and opens Remove dialog (UC-20 Screen #59)',
    (tester) async {
      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: const TravelGroupMembersPage(
              groupId: 42,
              isHost: true,
              currentUserId: 101,
            ),
          ),
        ),
      );

      // Host should NOT see remove button for Alice Host (BR-45)
      expect(find.byKey(const Key('remove_member_button_101')), findsNothing);

      // Host should see remove button for Bob Member (BR-45)
      expect(find.byKey(const Key('remove_member_button_102')), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byKey(const Key('remove_member_button_102')));
      await tester.pumpAndSettle();

      // Verify Screen #59 dialog opens with MSG59
      expect(find.byType(RemoveGroupMemberDialog), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to remove Bob Member from this group?',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Non-host viewer does not see Remove button for any member (BR-45)',
    (tester) async {
      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: const TravelGroupMembersPage(
              groupId: 42,
              isHost: false,
              currentUserId: 102,
            ),
          ),
        ),
      );

      expect(find.text('Remove'), findsNothing);
      expect(find.byKey(const Key('remove_member_button_101')), findsNothing);
      expect(find.byKey(const Key('remove_member_button_102')), findsNothing);
    },
  );

  testWidgets(
    'Stale or spoofed isHost flag is rejected when authoritative loaded data shows another Host',
    (tester) async {
      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: const TravelGroupMembersPage(
              groupId: 42,
              isHost: true, // Spoofed or stale extra
              currentUserId: 102, // Bob is NOT the authoritative host
            ),
          ),
        ),
      );

      expect(find.text('Remove'), findsNothing);
      expect(find.byKey(const Key('remove_member_button_101')), findsNothing);
      expect(find.byKey(const Key('remove_member_button_102')), findsNothing);
    },
  );

  testWidgets(
    'P2 Fail-Closed: When currentUserId is null, isHost route flag is rejected and Remove buttons are hidden',
    (tester) async {
      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: const TravelGroupMembersPage(
              groupId: 42,
              isHost: true, // GoRouter extra or constructor flag says Host
              currentUserId: null, // But user identity is unavailable
            ),
          ),
        ),
      );

      expect(find.text('Remove'), findsNothing);
      expect(find.byKey(const Key('remove_member_button_101')), findsNothing);
      expect(find.byKey(const Key('remove_member_button_102')), findsNothing);
    },
  );

  testWidgets(
    'P2 Authoritative Host: Viewer matching loaded host sees Remove button even if isHost is false or omitted',
    (tester) async {
      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: const TravelGroupMembersPage(
              groupId: 42,
              isHost: false, // isHost flag is false
              currentUserId: 101, // But user identity matches loaded host!
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('remove_member_button_102')), findsOneWidget);
    },
  );

  testWidgets('P2 Fail-Closed: Group with no designated host fails closed', (
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
              displayName: 'Alice Member',
              isHost: false,
              joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
              locationSharingEnabled: false,
            ),
            TravelGroupMember(
              memberId: 102,
              displayName: 'Bob Member',
              isHost: false,
              joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
          child: const TravelGroupMembersPage(
            groupId: 42,
            isHost: true,
            currentUserId: 101,
          ),
        ),
      ),
    );

    expect(find.text('Remove'), findsNothing);
  });

  testWidgets(
    'P2 Session Storage: Asynchronously resolves user ID from SecureStorageService JWT and reveals host controls',
    (tester) async {
      final storage = _FakeStorage();
      final header = _base64UrlEncodeJson({'alg': 'HS256', 'typ': 'JWT'});
      final payload = _base64UrlEncodeJson({'sub': '101'});
      await storage.write(AppConstants.accessTokenKey, '$header.$payload.sig');

      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: TravelGroupMembersPage(groupId: 42, storage: storage),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_member_button_102')), findsOneWidget);
    },
  );

  testWidgets(
    'P1 Scaffold: Opening Remove dialog from members page shows disabled confirm button',
    (tester) async {
      final cubit = TravelGroupMembersCubit(
        repository: _NeverCalledRepository(),
      );
      cubit.emitForTest(
        TravelGroupMembersSuccess(
          TravelGroupMembers(
            groupId: 42,
            groupName: 'Da Nang Weekend',
            itineraryId: 10,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Alice Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
                locationSharingEnabled: false,
              ),
              TravelGroupMember(
                memberId: 102,
                displayName: 'Bob Member',
                isHost: false,
                joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
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
            child: const TravelGroupMembersPage(
              groupId: 42,
              isHost: true,
              currentUserId: 101,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('remove_member_button_102')));
      await tester.pumpAndSettle();

      expect(find.byType(RemoveGroupMemberDialog), findsOneWidget);
      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const Key('remove_member_confirm_button')),
      );
      expect(confirmBtn.onPressed, isNull);
    },
  );
}

String _base64UrlEncodeJson(Map<String, dynamic> data) =>
    base64Url.encode(utf8.encode(json.encode(data)));

final class _FakeStorage implements SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
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
