import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';

final class GetOperatorProfileUseCase {
  const GetOperatorProfileUseCase(this._repository);

  final OperatorProfileRepository _repository;

  Future<OperatorProfile> call() => _repository.getProfile();
}

final class UpdateOperatorProfileUseCase {
  const UpdateOperatorProfileUseCase(this._repository);

  final OperatorProfileRepository _repository;

  Future<OperatorProfile> call(UpdateOperatorProfileInput input) {
    final normalized = input.normalized();
    final errors = OperatorProfileValidator.validate(normalized);
    if (errors.isNotEmpty) {
      return Future<OperatorProfile>.error(
        OperatorProfileValidationException(errors),
      );
    }
    return _repository.updateProfile(normalized);
  }
}
