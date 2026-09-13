import 'package:equatable/equatable.dart';

final class RegisterTravelerResponse extends Equatable {
  const RegisterTravelerResponse({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.emailSent,
    required this.messageCode,
  });

  factory RegisterTravelerResponse.fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final email = json['email'];
    final fullName = json['fullName'];
    final role = json['role'];
    final status = json['status'];
    final emailSent = json['emailSent'];
    final messageCode = json['messageCode'];

    if (userId is! int ||
        email is! String ||
        fullName is! String ||
        role is! String ||
        status is! String ||
        emailSent is! bool ||
        messageCode is! String) {
      throw const FormatException('Invalid traveler registration response.');
    }

    return RegisterTravelerResponse(
      userId: userId,
      email: email,
      fullName: fullName,
      role: role,
      status: status,
      emailSent: emailSent,
      messageCode: messageCode,
    );
  }

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
