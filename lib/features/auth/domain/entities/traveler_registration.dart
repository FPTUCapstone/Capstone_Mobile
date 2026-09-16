import 'package:equatable/equatable.dart';

final class TravelerRegistration {
  const TravelerRegistration({
    required this.fullName,
    required this.email,
    required this.password,
    required this.acceptedTerms,
    this.phoneNumber,
  });

  final String fullName;
  final String email;
  final String password;
  final bool acceptedTerms;
  final String? phoneNumber;
}

final class TravelerRegistrationResult extends Equatable {
  const TravelerRegistrationResult({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.emailSent,
    required this.messageCode,
  });

  final int userId;
  final String email;
  final String fullName;
  final String role;
  final String status;
  final bool emailSent;
  final String messageCode;

  @override
  List<Object?> get props => [
    userId,
    email,
    fullName,
    role,
    status,
    emailSent,
    messageCode,
  ];
}
