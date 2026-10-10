import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_cubit.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';

void main() {
  group('TourRecommendationsCubit', () {
    test('initial state has initial status', () {
      final cubit = TourRecommendationsCubit();
      addTearDown(cubit.close);

      expect(cubit.state.status, TourRecommendationsStatus.initial);
      expect(cubit.state.isDemoMode, isFalse);
    });

    test(
      'production mode emits pendingIntegration on load without fake data',
      () async {
        final cubit = TourRecommendationsCubit(isDemoMode: false);
        addTearDown(cubit.close);

        await cubit.load();

        expect(
          cubit.state.status,
          TourRecommendationsStatus.pendingIntegration,
        );
        expect(cubit.state.recommendations, isEmpty);
        expect(cubit.state.isDemoMode, isFalse);
      },
    );

    test(
      'demo mode loads deterministic recommendations with scores > 0.80',
      () async {
        final cubit = TourRecommendationsCubit(isDemoMode: true);
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, TourRecommendationsStatus.success);
        expect(cubit.state.recommendations, isNotEmpty);
        expect(cubit.state.isDemoMode, isTrue);

        // Verify all items have matchingScore > 0.80
        for (final rec in cubit.state.recommendations) {
          expect(rec.matchingScore, greaterThan(0.80));
        }

        // Verify descending order
        for (var i = 0; i < cubit.state.recommendations.length - 1; i++) {
          expect(
            cubit.state.recommendations[i].matchingScore,
            greaterThanOrEqualTo(
              cubit.state.recommendations[i + 1].matchingScore,
            ),
          );
        }
      },
    );

    test('demo mode paginates properly', () async {
      final cubit = TourRecommendationsCubit(isDemoMode: true);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.currentPage, 1);
      expect(cubit.state.totalPages, 2);

      cubit.loadDemoPage(2);
      expect(cubit.state.currentPage, 2);
      expect(cubit.state.recommendations, isNotEmpty);

      // Page boundary clamping
      cubit.loadDemoPage(99);
      expect(cubit.state.currentPage, 2);
    });

    test(
      'simulateNoPreferences emits noPreferences state with MSG28',
      () async {
        final cubit = TourRecommendationsCubit(isDemoMode: true);
        addTearDown(cubit.close);

        cubit.simulateNoPreferences();

        expect(cubit.state.status, TourRecommendationsStatus.noPreferences);
        expect(cubit.state.errorMessage, TourRecommendationsState.msg28);
      },
    );

    test('simulateNoMatches emits noMatches state with MSG64', () async {
      final cubit = TourRecommendationsCubit(isDemoMode: true);
      addTearDown(cubit.close);

      cubit.simulateNoMatches();

      expect(cubit.state.status, TourRecommendationsStatus.noMatches);
      expect(cubit.state.errorMessage, TourRecommendationsState.msg64);
    });

    test('simulateError emits error state with MSG127', () async {
      final cubit = TourRecommendationsCubit(isDemoMode: true);
      addTearDown(cubit.close);

      cubit.simulateError();

      expect(cubit.state.status, TourRecommendationsStatus.error);
      expect(cubit.state.errorMessage, TourRecommendationsState.msg127);
    });

    test('refresh calls load and updates state', () async {
      final cubit = TourRecommendationsCubit(isDemoMode: true);
      addTearDown(cubit.close);

      cubit.simulateError();
      expect(cubit.state.status, TourRecommendationsStatus.error);

      await cubit.refresh();
      expect(cubit.state.status, TourRecommendationsStatus.success);
    });
  });
}
