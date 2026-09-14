final class RegisterTravelerRequest {
  const RegisterTravelerRequest({
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

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'acceptedTerms': acceptedTerms,
    };
  }
}
