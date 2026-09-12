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

final class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
