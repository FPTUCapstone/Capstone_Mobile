import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_category.dart';

abstract interface class TourCategoryRepository {
  Future<List<TourCategory>> loadCategories();
}
