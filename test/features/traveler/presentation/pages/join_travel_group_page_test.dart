import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/join_travel_group_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

final class _MockTravelGroupRepository implements TravelGroupRepository {
  String? lastCode;
  String? lastKey;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async {
    lastCode = invitationCode;
    lastKey = idempotencyKey;
    return const TravelGroup(id: 42, name: 'Joined Group', itineraryId: 10);
  }
}

void main() {
  late _MockTravelGroupRepository repository;
  late JoinTravelGroupCubit cubit;

  setUp(() {
    repository = _MockTravelGroupRepository();
    cubit = JoinTravelGroupCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: BlocProvider<JoinTravelGroupCubit>.value(
        value: cubit,
        child: const JoinTravelGroupPage(),
      ),
    );
  }

  testWidgets('renders all required components and buttons', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Join Shared Group Trip'), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Join Group'), findsOneWidget);
    expect(find.text('Scan QR Invitation'), findsOneWidget);
  });

  testWidgets(
    'submitting empty code shows inline MSG01 without calling repository',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Join Group'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(repository.lastCode, isNull);
    },
  );

  testWidgets('submitting valid code calls repository and succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(AppTextField), 'A7K4P2QX');
    await tester.tap(find.widgetWithText(AppButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(repository.lastCode, 'A7K4P2QX');
    expect(repository.lastKey, isNotNull);
  });

  testWidgets(
    'typing lowercase characters converts them to uppercase and limits to 8',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AppTextField), 'hoian8kpxyz');
      await tester.pumpAndSettle();

      expect(find.text('HOIAN8KP'), findsOneWidget);
    },
  );

  testWidgets('tapping paste button populates code from clipboard', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': 'tripmate://groups/join?code=B2M4X7Q9'};
          }
          return null;
        });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.content_paste_rounded));
    await tester.pumpAndSettle();

    expect(find.text('B2M4X7Q9'), findsOneWidget);
  });
}
