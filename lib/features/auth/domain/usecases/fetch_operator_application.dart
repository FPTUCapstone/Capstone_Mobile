import 'package:trip_mate_mobile/features/auth/domain/entities/operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';

/// Reads the authoritative application state used by the status and resubmit screens.
final class FetchOperatorApplication {
  const FetchOperatorApplication(this._repository);

  final OperatorApplicationRepository _repository;

  Future<OperatorApplication> call() => _repository.fetchApplication();
}
