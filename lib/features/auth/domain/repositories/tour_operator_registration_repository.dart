import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';

abstract interface class TourOperatorRegistrationRepository {
  Future<TourOperatorRegistrationResult> register(
    TourOperatorRegistration registration,
    String firebaseIdToken,
  );

  /// Synchronizes verified Firebase evidence without issuing a TripMate session.
  Future<void> confirmVerifiedEmail(String firebaseIdToken);
}

/// BE has explicitly rejected the request without committing a registration.
final class OperatorRegistrationRejected implements Exception {
  const OperatorRegistrationRejected(
    this.messageCode, {
    this.fieldErrors = const {},
  });

  final String messageCode;
  final Map<String, List<String>> fieldErrors;
}

/// A transport or malformed response leaves the commit outcome unknown.
final class OperatorRegistrationUncertain implements Exception {
  const OperatorRegistrationUncertain();
}

final class OperatorVerificationRejected implements Exception {
  const OperatorVerificationRejected(this.messageCode);

  final String messageCode;
}

final class OperatorVerificationUncertain implements Exception {
  const OperatorVerificationUncertain();
}
