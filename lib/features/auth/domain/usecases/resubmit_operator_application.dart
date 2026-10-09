import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';

/// Keeps the presentation layer independent from the transport repository.
final class ResubmitOperatorApplicationUseCase {
  const ResubmitOperatorApplicationUseCase(this._repository);

  final OperatorApplicationRepository _repository;

  Future<void> call(ResubmitOperatorApplication input) =>
      _repository.resubmitApplication(input);
}
