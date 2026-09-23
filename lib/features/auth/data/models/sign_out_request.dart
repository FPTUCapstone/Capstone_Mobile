final class SignOutRequest {
  const SignOutRequest({this.refreshToken});

  final String? refreshToken;

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}
