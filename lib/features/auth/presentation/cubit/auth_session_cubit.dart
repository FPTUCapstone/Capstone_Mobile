import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

final class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit() : super(const AuthSessionState.unauthenticated());

  void clearPreviewSession() => emit(const AuthSessionState.unauthenticated());

  void previewAs(UserRole role) => emit(AuthSessionState.authenticated(role));
}
