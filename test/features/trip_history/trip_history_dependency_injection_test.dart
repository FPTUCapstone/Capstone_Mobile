import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
  });

  tearDown(() => serviceLocator.reset());

  test('container composes production and demo trip-history cubits', () {
    final production = serviceLocator<TripHistoryCubit>(param1: false);
    final demo = serviceLocator<TripHistoryCubit>(param1: true);
    addTearDown(production.close);
    addTearDown(demo.close);

    expect(production.isDemoMode, isFalse);
    expect(production.demoTravelerId, isNull);
    expect(demo.isDemoMode, isTrue);
    expect(demo.demoTravelerId, 1);
  });

  test(
    'demo history and review cubits share the container-owned store',
    () async {
      final history = serviceLocator<TripHistoryCubit>(param1: true);
      final review = serviceLocator<TripReviewCubit>(param1: true);
      addTearDown(history.close);
      addTearDown(review.close);

      await history.switchTab(TripStatus.completed);
      final trip = history.state.items.firstWhere(
        (item) => item.id == 'trip-tour-003',
      );
      review.initialize(trip: trip, travelerId: 1);
      review
        ..setRating(5)
        ..setTitle('Shared store')
        ..setContent(
          'The shared dependency graph keeps review state consistent.',
        );
      await review.submit();

      await history.refresh();
      final refreshed = history.state.items.firstWhere(
        (item) => item.id == 'trip-tour-003',
      );
      expect(refreshed.review?.title, 'Shared store');
    },
  );

  test(
    'F-08: production repositories fail closed without demo store dependency',
    () async {
      final historyRepo = serviceLocator<TripHistoryRepository>(param1: false);
      final reviewRepo = serviceLocator<TripReviewRepository>(param1: false);

      expect(historyRepo, isA<TripHistoryRepositoryImpl>());
      expect((historyRepo as TripHistoryRepositoryImpl).isDemoMode, isFalse);
      expect(reviewRepo, isA<TripReviewRepositoryImpl>());
      expect((reviewRepo as TripReviewRepositoryImpl).isDemoMode, isFalse);

      expect(() => historyRepo.getTrips(), throwsA(isA<ServerFailure>()));
      expect(
        () => historyRepo.getTripById(tripId: 'any-id'),
        throwsA(isA<ServerFailure>()),
      );
      expect(
        () => reviewRepo.getReviewForTrip(tripId: 'any-id'),
        throwsA(isA<ServerFailure>()),
      );
    },
  );
}
