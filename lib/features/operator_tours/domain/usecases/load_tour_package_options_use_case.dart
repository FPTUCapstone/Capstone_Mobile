import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';

final class LoadTourPackageOptionsUseCase {
  const LoadTourPackageOptionsUseCase(this._repository);
  final OperatorTourRepository _repository;
  Future<TourPackageOptions> call() => _repository.loadOptions();
}
