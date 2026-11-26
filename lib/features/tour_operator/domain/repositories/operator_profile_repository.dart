import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';

enum OperatorProfileFailureKind {
  unauthorized,
  forbidden,
  notFound,
  unavailable,
  unknown,
}

final class OperatorProfileValidationException implements Exception {
  const OperatorProfileValidationException(this.errors);

  final OperatorProfileValidationErrors errors;
}

final class OperatorProfileFailureException implements Exception {
  const OperatorProfileFailureException({
    required this.kind,
    required this.message,
    this.errorCode,
  });

  final OperatorProfileFailureKind kind;
  final String message;
  final String? errorCode;
}

abstract interface class OperatorProfileRepository {
  Future<OperatorProfile> getProfile();

  Future<OperatorProfile> updateProfile(UpdateOperatorProfileInput input);
}
