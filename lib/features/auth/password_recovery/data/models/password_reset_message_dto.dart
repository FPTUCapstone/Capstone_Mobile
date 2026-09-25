final class PasswordResetMessageDto {
  const PasswordResetMessageDto({required this.message});

  factory PasswordResetMessageDto.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is! String || message.trim().isEmpty) {
      throw const FormatException('Invalid password-reset success response.');
    }
    return PasswordResetMessageDto(message: message.trim());
  }

  final String message;
}
