import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/travel_group_details_route_args.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_travel_group_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

final class _MockRepository implements TravelGroupRepository {
  String? lastSubmittedName;
  int? lastSubmittedItineraryId;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    lastSubmittedName = name;
    lastSubmittedItineraryId = itineraryId;
    return TravelGroup(id: 1, name: name);
  }

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async {
    return const TravelGroup(id: 1, name: 'Test Group', inviteCode: 'ABC12345');
  }
}

void main() {
  late _MockRepository repository;
  late CreateTravelGroupCubit cubit;

  setUp(() {
    repository = _MockRepository();
    cubit = CreateTravelGroupCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildSubject({
    int itineraryId = 10,
    String itineraryTitle = 'Summer trip',
  }) {
    return MaterialApp(
      home: BlocProvider<CreateTravelGroupCubit>.value(
        value: cubit,
        child: CreateTravelGroupPage(
          itineraryId: itineraryId,
          itineraryTitle: itineraryTitle,
        ),
      ),
    );
  }

  testWidgets('renders the selected itinerary as read-only association', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final textFields = find.byType(AppTextField);
    expect(textFields, findsNWidgets(2));

    final nameField = tester.widget<AppTextField>(textFields.at(0));
    expect(nameField.controller?.text, isEmpty);

    final itineraryField = tester.widget<AppTextField>(textFields.at(1));
    expect(itineraryField.controller?.text, 'Summer trip');
    expect(itineraryField.readOnly, isTrue);
    expect(itineraryField.onTap, isNull);
  });

  testWidgets('shows MSG01 when submitting with an empty group name', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsOneWidget);
    expect(repository.lastSubmittedName, isNull);
  });

  testWidgets('submits with the selected itinerary id when the name is valid', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Da Nang Trip 2026');

    await tester.tap(find.text('Create Group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(repository.lastSubmittedName, 'Da Nang Trip 2026');
    expect(repository.lastSubmittedItineraryId, 10);
  });
  testWidgets(
    'successful creation routes to details with trusted Host context',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(
            path: '/create',
            builder: (_, _) => BlocProvider<CreateTravelGroupCubit>.value(
              value: cubit,
              child: const CreateTravelGroupPage(
                itineraryId: 10,
                itineraryTitle: 'Summer trip',
              ),
            ),
          ),
          GoRoute(
            path: '/groups/:groupId',
            name: AppRouteNames.travelGroupDetails,
            builder: (_, state) {
              final args = state.extra! as TravelGroupDetailsRouteArgs;
              return Text('${args.group.id}:${args.isHost}');
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.enterText(find.byType(TextFormField).first, 'Da Nang Trip');
      await tester.tap(find.text('Create Group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('1:true'), findsOneWidget);
    },
  );
}
