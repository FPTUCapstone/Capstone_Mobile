import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Please check your connection.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'The service is currently unavailable.']);
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Please sign in to continue.']);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'You do not have permission to access this function.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const <String, List<String>>{},
  });

  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Địa điểm không tồn tại hoặc đã đóng.']);
}

final class LocationPermissionFailure extends Failure {
  const LocationPermissionFailure([
    super.message = 'Không thể dùng vị trí. Bạn vẫn có thể khám phá các địa điểm.',
  ]);
}

final class ConflictFailure extends Failure {
  const ConflictFailure([
    super.message = 'Conflict occurred. Please try again.',
    this.groupId,
  ]);

  final int? groupId;

  @override
  List<Object?> get props => [message, groupId];
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong. Please try again.']);
}
