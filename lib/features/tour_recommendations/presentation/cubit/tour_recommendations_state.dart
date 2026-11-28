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
        errorMessage: msg183,
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

  /// MSG183: Add at least one interest tag in Travel Preferences (current SRS).
  static const String msg183 =
      'Vui lòng chọn ít nhất một thẻ sở thích trong mục Sở thích du lịch để nhận gợi ý tour phù hợp.';

  /// MSG64: No tours reach the similarity threshold (> 80%).
  static const String msg64 =
      'Hiện chưa có tour nào đạt ngưỡng độ phù hợp (> 80%). Hãy thử cập nhật sở thích hoặc khám phá tất cả tour.';

  /// MSG127: System/network failure.
  static const String msg127 =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối và thử lại.';

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
