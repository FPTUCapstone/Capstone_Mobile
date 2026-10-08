final class RegisterOperatorResponse {
  const RegisterOperatorResponse({
    required this.userId,
    required this.applicationStatus,
    required this.messageCode,
  });

  factory RegisterOperatorResponse.fromEnvelope(int? statusCode, Object? body) {
    if (statusCode != 201 ||
        body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid operator registration response.');
    }
    final data = body['data'] as Map<String, dynamic>;
    final userId = data['userId'];
    final status = data['applicationStatus'];
    final code = data['messageCode'];
    if (userId is! int ||
        userId <= 0 ||
        status != 'PendingApproval' ||
        code != 'MSG08') {
      throw const FormatException('Invalid operator registration response.');
    }
    return RegisterOperatorResponse(
      userId: userId,
      applicationStatus: status as String,
      messageCode: code as String,
    );
  }

  final int userId;
  final String applicationStatus;
  final String messageCode;
}
