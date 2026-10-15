final class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  /// Exactly these two fields — no user ID, role, email, or confirmation
  /// (UC-07 spec §4): the subject comes from the authenticated access token.
  Map<String, dynamic> toJson() => {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };
}
