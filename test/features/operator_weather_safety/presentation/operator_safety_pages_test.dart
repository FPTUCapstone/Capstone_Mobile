import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/operator_safety_review_detail_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/operator_safety_reviews_page.dart';

import '../support/fake_operator_weather_safety_repository.dart';

void main() {
  late FakeOperatorWeatherSafetyRepository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = FakeOperatorWeatherSafetyRepository();
    network = FakeNetworkInfo();
  });

  group('inbox page', () {
    Future<OperatorSafetyReviewsCubit> pump(WidgetTester tester) async {
      final cubit = OperatorSafetyReviewsCubit(
        getReviews: GetWeatherSafetyReviewsUseCase(repository),
        networkInfo: network,
        realtime: _IdleRealtime(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const OperatorSafetyReviewsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets(
      'any route covering the list pauses the poll until it returns',
      (tester) async {
        final cubit = await pump(tester);
        expect(cubit.isInboxVisible, isTrue);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();
        expect(cubit.isInboxVisible, isFalse);

        navigator.pop();
        await tester.pumpAndSettle();
        expect(cubit.isInboxVisible, isTrue);
      },
    );

    testWidgets('status is conveyed by text and an icon, not colour alone', (
      tester,
    ) async {
      repository.reviews = [
        review(id: 2, status: WeatherSafetyReviewStatus.escalated),
        review(id: 1, status: WeatherSafetyReviewStatus.acknowledged),
      ];

      await pump(tester);

      expect(find.text('ESCALATED'), findsOneWidget);
      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('filters by status', (tester) async {
      repository.reviews = [
        review(id: 2, status: WeatherSafetyReviewStatus.escalated),
        review(id: 1, status: WeatherSafetyReviewStatus.acknowledged),
      ];
      await pump(tester);

      await tester.tap(find.byKey(const Key('safety-filter-acknowledged')));
      await tester.pumpAndSettle();

      expect(find.text('ESCALATED'), findsNothing);
      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
    });

    testWidgets('an empty inbox says so', (tester) async {
      await pump(tester);

      expect(find.text('No safety alerts'), findsOneWidget);
    });

    testWidgets('an error offers a retry', (tester) async {
      repository.failure = const ServerFailure();
      await pump(tester);
      expect(find.text('Try again'), findsOneWidget);

      repository
        ..failure = null
        ..reviews = [review()];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Hue heritage day tour'), findsOneWidget);
    });

    testWidgets('offline keeps the list and labels it as out of date', (
      tester,
    ) async {
      repository.reviews = [review()];
      final cubit = await pump(tester);

      network.connected = false;
      await cubit.refresh();
      await tester.pumpAndSettle();

      expect(find.text('Hue heritage day tour'), findsOneWidget);
      expect(find.textContaining('out of date'), findsOneWidget);
    });

    testWidgets('being visible enables polling and leaving disables it', (
      tester,
    ) async {
      final cubit = await pump(tester);
      expect(cubit.isInboxVisible, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(cubit.isInboxVisible, isFalse);
    });
  });

  group('review detail page', () {
    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onChanged,
      double textScale = 1,
      Size size = const Size(400, 800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = OperatorSafetyReviewDetailCubit(
        reviewId: 7,
        getReview: GetWeatherSafetyReviewUseCase(repository),
        acknowledge: AcknowledgeWeatherSafetyReviewUseCase(repository),
        networkInfo: network,
      );
      addTearDown(cubit.close);
      unawaited(cubit.load());
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: BlocProvider.value(
            value: cubit,
            child: OperatorSafetyReviewDetailPage(onChanged: onChanged),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows server fields and offers no Continue Tour', (
      tester,
    ) async {
      repository.reviewResult = review();

      await pump(tester);

      expect(find.text('Hue heritage day tour'), findsOneWidget);
      expect(find.textContaining('Storm'), findsWidgets);
      expect(find.textContaining('Continue'), findsNothing);
    });

    testWidgets('unknown weather fields do not invent text', (tester) async {
      repository.reviewResult = review();

      await pump(tester);

      expect(find.textContaining('null'), findsNothing);
      expect(find.text('Not provided'), findsWidgets);
    });

    testWidgets('acknowledging updates the view and tells the inbox', (
      tester,
    ) async {
      var changed = 0;
      repository
        ..reviewResult = review()
        ..acknowledgeResult = review(
          status: WeatherSafetyReviewStatus.acknowledged,
        );
      await pump(tester, onChanged: () => changed++);

      await tester.ensureVisible(find.byKey(const Key('safety-acknowledge')));
      await tester.tap(find.byKey(const Key('safety-acknowledge')));
      await tester.pumpAndSettle();

      expect(repository.acknowledgeCalls, 1);
      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
      expect(find.byKey(const Key('safety-acknowledge')), findsNothing);
      expect(changed, 1);
    });

    testWidgets('acknowledging explains it changes nothing about the tour', (
      tester,
    ) async {
      repository.reviewResult = review();

      await pump(tester);

      expect(find.textContaining('does not change the tour'), findsOneWidget);
    });

    testWidgets('a double tap sends one acknowledgement', (tester) async {
      repository
        ..reviewResult = review()
        ..acknowledgeResult = review(
          status: WeatherSafetyReviewStatus.acknowledged,
        );
      await pump(tester);
      repository.gate = Completer<void>();

      final button = find.byKey(const Key('safety-acknowledge'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(repository.acknowledgeCalls, 1);
    });

    testWidgets('a foreign review is a Safe 404 that names nothing', (
      tester,
    ) async {
      repository.failure = const NotFoundFailure();

      await pump(tester);

      expect(find.text('Safety alert not found'), findsOneWidget);
      expect(find.text('Hue heritage day tour'), findsNothing);
    });

    testWidgets('a decided departure links to evidence, not a new decision', (
      tester,
    ) async {
      repository.reviewResult = review(scheduleStatus: 'EmergencyStopped');

      await pump(tester);

      expect(find.byKey(const Key('safety-manage-evidence')), findsOneWidget);
      expect(find.byKey(const Key('safety-open-decision')), findsNothing);
    });

    testWidgets('long text fits a small screen with large text', (
      tester,
    ) async {
      repository.reviewResult = review(
        immediateInstructions: List.filled(
          60,
          'Keep guests indoors.',
        ).join(' '),
      );

      await pump(tester, textScale: 2, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
    });
  });
}

final class _IdleRealtime implements OperatorWeatherSafetyRealtime {
  @override
  Stream<bool> get connection => const Stream.empty();

  @override
  Stream<WeatherSafetyReviewHint> get hints => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
