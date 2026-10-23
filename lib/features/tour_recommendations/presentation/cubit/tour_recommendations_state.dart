import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendation.dart';

enum TourRecommendationsStatus {
  initial,
  loading,
  pendingIntegration,
  noPreferences,
  noMatches,
  error,
  success,
}

final class TourRecommendationsState extends Equatable {
  const TourRecommendationsState({
    required this.status,
    this.recommendations = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.errorMessage,
    this.isDemoMode = false,
  });

  const TourRecommendationsState.initial({bool isDemoMode = false})
    : this(status: TourRecommendationsStatus.initial, isDemoMode: isDemoMode);

  const TourRecommendationsState.loading({
    List<TourRecommendation> recommendations = const [],
    int currentPage = 1,
    int totalPages = 1,
    int totalItems = 0,
    bool isDemoMode = false,
  }) : this(
         status: TourRecommendationsStatus.loading,
         recommendations: recommendations,
         currentPage: currentPage,
         totalPages: totalPages,
         totalItems: totalItems,
         isDemoMode: isDemoMode,
       );

  const TourRecommendationsState.pendingIntegration({bool isDemoMode = false})
    : this(
        status: TourRecommendationsStatus.pendingIntegration,
        isDemoMode: isDemoMode,
      );

  const TourRecommendationsState.noPreferences({bool isDemoMode = false})
    : this(
        status: TourRecommendationsStatus.noPreferences,
        errorMessage: msg28,
        isDemoMode: isDemoMode,
      );

  const TourRecommendationsState.noMatches({bool isDemoMode = false})
    : this(
        status: TourRecommendationsStatus.noMatches,
        errorMessage: msg64,
        isDemoMode: isDemoMode,
      );

  const TourRecommendationsState.error(
    String message, {
    bool isDemoMode = false,
  }) : this(
         status: TourRecommendationsStatus.error,
         errorMessage: message,
         isDemoMode: isDemoMode,
       );

  const TourRecommendationsState.success({
    required List<TourRecommendation> recommendations,
    int currentPage = 1,
    int totalPages = 1,
    int totalItems = 0,
    bool isDemoMode = false,
  }) : this(
         status: TourRecommendationsStatus.success,
         recommendations: recommendations,
         currentPage: currentPage,
         totalPages: totalPages,
         totalItems: totalItems,
         isDemoMode: isDemoMode,
       );

  final TourRecommendationsStatus status;
  final List<TourRecommendation> recommendations;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final String? errorMessage;
  final bool isDemoMode;

  bool get isLoading => status == TourRecommendationsStatus.loading;
  bool get hasMore => currentPage < totalPages;

  /// MSG28: No interest tag configured.
  static const String msg28 =
      'Please configure at least one travel interest tag in Travel Preferences to receive personalized tour recommendations.';

  /// MSG64: No tours reach the similarity threshold (> 80%).
  static const String msg64 =
      'No tours currently reach the recommendation threshold (> 80%). Try updating your preferences or explore all tours.';

  /// MSG127: System/network failure.
  static const String msg127 =
      'TripMate is temporarily unable to process your request. Please check your connection and try again.';

  TourRecommendationsState copyWith({
    TourRecommendationsStatus? status,
    List<TourRecommendation>? recommendations,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    String? errorMessage,
    bool? isDemoMode,
  }) {
    return TourRecommendationsState(
      status: status ?? this.status,
      recommendations: recommendations ?? this.recommendations,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      errorMessage: errorMessage ?? this.errorMessage,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    recommendations,
    currentPage,
    totalPages,
    totalItems,
    errorMessage,
    isDemoMode,
  ];
}
