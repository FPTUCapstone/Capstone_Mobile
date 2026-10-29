import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_category.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_category_repository.dart';

final class LoadTourCategoriesUseCase {
  const LoadTourCategoriesUseCase(this._repository);
  final TourCategoryRepository _repository;
  Future<List<TourCategory>> call() => _repository.loadCategories();
}
