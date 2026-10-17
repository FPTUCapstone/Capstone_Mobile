import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';

enum AuthSessionStatus {
  unauthenticated,
  loading,
  authenticated,
  verificationEmailSent,
  failure,
}

enum AuthSessionOperation {
  none,
  verifyEmail,
  resendVerificationEmail,
  signOut,
}

final class AuthSessionState extends Equatable {
  const AuthSessionState._({
    required this.status,
    this.errorMessage,
    this.role,
    this.applicationStatus = TourOperatorApplicationStatus.unresolved,
    this.operation = AuthSessionOperation.none,
    this.startResendCooldown = false,
    this.successMessage,
    this.fullName,
    this.email,
  });

  const AuthSessionState.authenticated(
    UserRole role, {
    TourOperatorApplicationStatus applicationStatus =
        TourOperatorApplicationStatus.unresolved,
    AuthSessionOperation operation = AuthSessionOperation.none,
    String? errorMessage,
    String? fullName,
    String? email,
  }) : this._(
         status: AuthSessionStatus.authenticated,
         role: role,
         applicationStatus: applicationStatus,
         operation: operation,
         errorMessage: errorMessage,
         fullName: fullName,
         email: email,
       );

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

  /// The session is unauthenticated. An optional [errorMessage] carries a
  /// one-shot notice produced by a completed local sign-out, so the login
  /// screen can present it without a separate notice store.
  const AuthSessionState.unauthenticated({String? errorMessage})
    : this._(
        status: AuthSessionStatus.unauthenticated,
        errorMessage: errorMessage,
      );

  final String? errorMessage;
  final AuthSessionOperation operation;
  final UserRole? role;

  /// Backend-issued Tour Operator application status mapped by Data. Unknown
  /// and non-operator values remain explicitly unresolved.
  final TourOperatorApplicationStatus applicationStatus;

  /// Backend-issued identity snapshot from the real `AuthSession`; null when
  /// the Backend did not supply it. Never a fallback or inferred value.
  final String? fullName;
  final String? email;
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
    applicationStatus,
    errorMessage,
    operation,
    startResendCooldown,
    successMessage,
    fullName,
    email,
  ];
}
