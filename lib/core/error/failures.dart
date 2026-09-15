import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Please check your connection.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'The service is currently unavailable.',
  ]);
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Please sign in to continue.']);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'You do not have permission to access this function.',
  ]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class ConflictFailure extends Failure {
  const ConflictFailure([
    super.message = 'This request conflicts with an existing operation.',
  ]);
}

final class ConstraintFailure extends Failure {
  const ConstraintFailure([
    super.message =
        'Your selected time, locations, or budget cannot form an itinerary.',
  ]);
}

final class DailyLimitFailure extends Failure {
  const DailyLimitFailure([
    super.message =
        'You can generate up to 3 itineraries per day. Please try again tomorrow.',
  ]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
