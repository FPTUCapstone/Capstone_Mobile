import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_travel_group_page.dart';

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

  Widget buildSubject({int? itineraryId, String? itineraryTitle}) {
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

  testWidgets(
    'renders empty input fields by default without pre-assigned values',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      // Both fields start empty
      final nameField = tester.widget<TextFormField>(textFields.at(0));
      expect(nameField.controller?.text, isEmpty);

      final itineraryField = tester.widget<TextFormField>(textFields.at(1));
      expect(itineraryField.controller?.text, isEmpty);
    },
  );

  testWidgets('shows validation error when submitting with empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('Itinerary ID is required.'), findsOneWidget);
    expect(repository.lastSubmittedName, isNull);
  });

  testWidgets(
    'submits successfully when user inputs group name and itinerary id',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Da Nang Trip 2026');
      await tester.enterText(textFields.at(1), '1');

      await tester.tap(find.text('Create Group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(repository.lastSubmittedName, 'Da Nang Trip 2026');
      expect(repository.lastSubmittedItineraryId, 1);
    },
  );
}
