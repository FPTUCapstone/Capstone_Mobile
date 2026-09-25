final class PasswordResetRequest {
  const PasswordResetRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};
}
