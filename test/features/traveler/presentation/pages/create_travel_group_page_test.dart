import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) async {
    lastSubmittedName = name;
    lastSubmittedItineraryId = itineraryId;
    return TravelGroup(id: 1, name: name);
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
}
