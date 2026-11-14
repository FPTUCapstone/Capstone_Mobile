import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/datasources/tour_recommendations_data_source.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/repositories/tour_recommendations_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_result.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/usecases/get_tour_recommendations.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';

/// Cubit managing Tour Recommendations for UC-25.
///
/// Follows Clean Architecture: Page -> Cubit -> UseCase -> Repository -> DataSource.
/// Production mode strictly exposes [TourRecommendationsStatus.pendingIntegration].
/// Demo mode is strictly isolated to debug review (`kDebugMode && ?demo=true`).
final class TourRecommendationsCubit extends Cubit<TourRecommendationsState> {
  TourRecommendationsCubit({
    GetTourRecommendations? getTourRecommendations,
    this.isDemoMode = false,
  }) : _getTourRecommendations =
           getTourRecommendations ??
           (isDemoMode
               ? const GetTourRecommendations(
                   TourRecommendationsRepositoryImpl(
                     DemoTourRecommendationsDataSource(),
                   ),
                 )
               : (serviceLocator.isRegistered<GetTourRecommendations>()
                     ? serviceLocator<GetTourRecommendations>()
                     : const GetTourRecommendations(
                         TourRecommendationsRepositoryImpl(
                           PendingTourRecommendationsDataSource(),
                         ),
                       ))),
       super(TourRecommendationsState.initial(isDemoMode: isDemoMode));

  final GetTourRecommendations _getTourRecommendations;
  final bool isDemoMode;
  Future<void>? _refreshInFlight;
  int _requestSequence = 0;

  /// Loads initial recommendations.
  Future<void> load({
    bool hasPreferences = true,
    int page = 1,
    bool refresh = false,
  }) async {
    if (refresh && _refreshInFlight != null) return _refreshInFlight!;
    final operation = _load(
      hasPreferences: hasPreferences,
      page: page,
      refresh: refresh,
    );
    if (!refresh) return operation;
    _refreshInFlight = operation.whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  Future<void> _load({
    required bool hasPreferences,
    required int page,
    required bool refresh,
  }) async {
    final requestId = ++_requestSequence;
    if (state.recommendations.isEmpty) {
      emit(TourRecommendationsState.loading(isDemoMode: isDemoMode));
    }

    try {
      final result = await _getTourRecommendations(
        TourRecommendationsQuery(
          page: page,
          hasPreferences: hasPreferences,
          refresh: refresh,
        ),
      );
      if (requestId != _requestSequence) return;

      switch (result) {
        case TourRecommendationsPending():
          emit(
            TourRecommendationsState.pendingIntegration(isDemoMode: isDemoMode),
          );
        case TourRecommendationsNoPreferences():
          emit(TourRecommendationsState.noPreferences(isDemoMode: isDemoMode));
        case TourRecommendationsNoMatches():
          emit(TourRecommendationsState.noMatches(isDemoMode: isDemoMode));
        case TourRecommendationsSuccess(
          :final recommendations,
          :final currentPage,
          :final totalPages,
          :final totalItems,
        ):
          emit(
            TourRecommendationsState.success(
              recommendations: recommendations,
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: totalItems,
              isDemoMode: isDemoMode,
            ),
          );
      }
    } on Object {
      if (requestId != _requestSequence) return;
      if (state.recommendations.isNotEmpty) {
        emit(
          state.copyWith(
            status: TourRecommendationsStatus.success,
            errorMessage: TourRecommendationsState.msg127,
          ),
        );
      } else {
        emit(
          TourRecommendationsState.error(
            TourRecommendationsState.msg127,
            isDemoMode: isDemoMode,
          ),
        );
      }
    }
  }

  /// Refreshes recommendations.
  Future<void> refresh() async {
    await load(page: 1, refresh: true);
  }

  Future<void> loadPage(int page) => load(page: page);

  /// Loads a specific page in Demo Mode.
  Future<void> loadDemoPage(int page) async {
    await loadPage(page);
  }

  /// Simulates MSG183 state in Demo Mode (no interest tags configured).
  void simulateNoPreferences() {
    if (!isDemoMode) return;
    emit(const TourRecommendationsState.noPreferences(isDemoMode: true));
  }

  /// Simulates MSG64 state in Demo Mode (no tours reach > 80% threshold).
  void simulateNoMatches() {
    if (!isDemoMode) return;
    emit(const TourRecommendationsState.noMatches(isDemoMode: true));
  }

  /// Simulates MSG127 state in Demo Mode (system/network failure).
  void simulateError() {
    if (!isDemoMode) return;
    emit(
      const TourRecommendationsState.error(
        TourRecommendationsState.msg127,
        isDemoMode: true,
      ),
    );
  }
}
