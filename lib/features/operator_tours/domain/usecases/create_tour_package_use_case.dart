import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';

final class CreateTourPackageUseCase {
  const CreateTourPackageUseCase(this._repository);
  final OperatorTourRepository _repository;
  Future<int> call(TourPackageDraft draft, String idempotencyKey) =>
      _repository.createDraft(draft, idempotencyKey);
}
