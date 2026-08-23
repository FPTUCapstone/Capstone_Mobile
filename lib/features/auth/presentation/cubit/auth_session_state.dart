import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';

enum AuthSessionStatus { unauthenticated, authenticated }

final class AuthSessionState extends Equatable {
  const AuthSessionState._({required this.status, this.role});

  const AuthSessionState.authenticated(UserRole role)
    : this._(status: AuthSessionStatus.authenticated, role: role);

  const AuthSessionState.unauthenticated()
    : this._(status: AuthSessionStatus.unauthenticated);

  final UserRole? role;
  final AuthSessionStatus status;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;

  @override
  List<Object?> get props => [status, role];
}
