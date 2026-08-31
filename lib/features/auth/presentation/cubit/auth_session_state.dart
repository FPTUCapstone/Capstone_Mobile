import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/demo/auth_demo_data.dart';

enum AuthSessionStatus { unauthenticated, loading, authenticated, failure }

final class AuthSessionState extends Equatable {
  const AuthSessionState._({
    required this.status,
    this.accountType,
    this.errorMessage,
    this.role,
  });

  const AuthSessionState.authenticated(
    UserRole role, {
    DemoAccountType? accountType,
  }) : this._(
         status: AuthSessionStatus.authenticated,
         role: role,
         accountType: accountType,
       );

  const AuthSessionState.failure(String message)
    : this._(status: AuthSessionStatus.failure, errorMessage: message);

  const AuthSessionState.loading() : this._(status: AuthSessionStatus.loading);

  const AuthSessionState.unauthenticated()
    : this._(status: AuthSessionStatus.unauthenticated);

  final DemoAccountType? accountType;
  final String? errorMessage;
  final UserRole? role;
  final AuthSessionStatus status;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;
  bool get isLoading => status == AuthSessionStatus.loading;
  bool get isRejectedOperator =>
      accountType == DemoAccountType.rejectedOperator;

  @override
  List<Object?> get props => [status, role, accountType, errorMessage];
}
