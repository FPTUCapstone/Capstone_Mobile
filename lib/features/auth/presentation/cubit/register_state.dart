import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';

sealed class RegisterState extends Equatable {
  const RegisterState();

  @override
  List<Object?> get props => [];
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess(this.response);

  final RegisterTravelerResponse response;

  @override
  List<Object?> get props => [response];
}

final class RegisterFailure extends RegisterState {
  const RegisterFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
