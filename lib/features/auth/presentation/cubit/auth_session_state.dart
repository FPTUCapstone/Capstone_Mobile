import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';

enum AuthSessionStatus {
  unauthenticated,
  loading,
  authenticated,
  verificationEmailSent,
  failure,
}

enum AuthSessionOperation { none, verifyEmail, resendVerificationEmail }

final class AuthSessionState extends Equatable {
  const AuthSessionState._({
    required this.status,
    this.errorMessage,
    this.role,
    this.operation = AuthSessionOperation.none,
    this.startResendCooldown = false,
    this.successMessage,
  });

  const AuthSessionState.authenticated(UserRole role)
    : this._(status: AuthSessionStatus.authenticated, role: role);

  const AuthSessionState.failure(
    String message, {
    bool startResendCooldown = false,
  }) : this._(
         status: AuthSessionStatus.failure,
         errorMessage: message,
         startResendCooldown: startResendCooldown,
       );

  const AuthSessionState.loading({
    AuthSessionOperation operation = AuthSessionOperation.none,
  }) : this._(status: AuthSessionStatus.loading, operation: operation);

  const AuthSessionState.verificationEmailSent(String message)
    : this._(
        status: AuthSessionStatus.verificationEmailSent,
        startResendCooldown: true,
        successMessage: message,
      );

  const AuthSessionState.unauthenticated()
    : this._(status: AuthSessionStatus.unauthenticated);

  final String? errorMessage;
  final AuthSessionOperation operation;
  final UserRole? role;
  final bool startResendCooldown;
  final AuthSessionStatus status;
  final String? successMessage;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;
  bool get isLoading => status == AuthSessionStatus.loading;
  bool get isResendingVerificationEmail =>
      isLoading && operation == AuthSessionOperation.resendVerificationEmail;

  @override
  List<Object?> get props => [
    status,
    role,
    errorMessage,
    operation,
    startResendCooldown,
    successMessage,
  ];
}
