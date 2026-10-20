import 'package:equatable/equatable.dart';

final class TourRecommendationsQuery extends Equatable {
  const TourRecommendationsQuery({
    this.page = 1,
    this.pageSize = 3,
    this.hasPreferences = true,
  }) : assert(page > 0),
       assert(pageSize > 0);

  final int page;
  final int pageSize;
  final bool hasPreferences;

  @override
  List<Object?> get props => [page, pageSize, hasPreferences];
}
