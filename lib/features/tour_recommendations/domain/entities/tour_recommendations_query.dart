import 'package:equatable/equatable.dart';

final class TourRecommendationsQuery extends Equatable {
  const TourRecommendationsQuery({
    this.page = 1,
    this.pageSize = 20,
    this.hasPreferences = true,
    this.refresh = false,
    this.destination,
    this.startDate,
    this.endDate,
    this.minBudget,
    this.maxBudget,
  }) : assert(page > 0),
       assert(pageSize > 0);

  final int page;
  final int pageSize;
  final bool hasPreferences;
  final bool refresh;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minBudget;
  final int? maxBudget;

  @override
  List<Object?> get props => [
    page,
    pageSize,
    hasPreferences,
    refresh,
    destination,
    startDate,
    endDate,
    minBudget,
    maxBudget,
  ];
}
