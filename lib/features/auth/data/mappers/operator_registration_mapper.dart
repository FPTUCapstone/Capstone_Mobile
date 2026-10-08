import 'package:trip_mate_mobile/features/auth/data/models/register_operator_response.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';

extension RegisterOperatorResponseMapper on RegisterOperatorResponse {
  TourOperatorRegistrationResult toDomain() => TourOperatorRegistrationResult(
    userId: userId,
    applicationStatus: applicationStatus,
    messageCode: messageCode,
  );
}

final class OperatorRegistrationRemoteRejection implements Exception {
  const OperatorRegistrationRemoteRejection(this.statusCode, this.body);

  final int statusCode;
  final Object? body;

  OperatorRegistrationRejected toDomain() {
    final json = body is Map<String, dynamic>
        ? body as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawCode = json['errorCode'];
    final code =
        _knownCode(rawCode) ??
        switch (statusCode) {
          401 => 'AUTH_TOKEN_INVALID',
          409 => 'auth.request_invalid',
          503 => 'MSG127',
          _ => 'auth.request_invalid',
        };
    final rawErrors = json['errors'];
    final fieldErrors = <String, List<String>>{};
    if (rawErrors is Map<String, dynamic>) {
      for (final entry in rawErrors.entries) {
        final field = _normalizeField(entry.key);
        if (field == null || entry.value is! List) {
          continue;
        }
        final messages = (entry.value as List)
            .whereType<String>()
            .map((value) => _messageForCode(value, field))
            .toList(growable: false);
        if (messages.isNotEmpty) {
          fieldErrors.putIfAbsent(field, () => <String>[]).addAll(messages);
        }
      }
    }
    return OperatorRegistrationRejected(code, fieldErrors: fieldErrors);
  }
}

final class OperatorRegistrationRemoteUnknown implements Exception {
  const OperatorRegistrationRemoteUnknown();
}

final class OperatorVerificationRemoteRejection implements Exception {
  const OperatorVerificationRemoteRejection(this.body);

  final Object? body;

  OperatorVerificationRejected toDomain() {
    final json = body is Map<String, dynamic>
        ? body as Map<String, dynamic>
        : const <String, dynamic>{};
    final code = switch (json['errorCode']) {
      'MSG_EMAIL_NOT_VERIFIED' ||
      'MSG14' ||
      'AUTH_HEADER_MISSING' ||
      'AUTH_TOKEN_INVALID' ||
      'auth.verification_unavailable' ||
      'auth.verification_email_missing' ||
      'MSG_USER_NOT_FOUND' ||
      'auth.account_locked' ||
      'auth.account_inactive' => json['errorCode'] as String,
      _ => 'MSG127',
    };
    return OperatorVerificationRejected(code);
  }
}

final class OperatorVerificationRemoteUnknown implements Exception {
  const OperatorVerificationRemoteUnknown();
}

const _knownFields = <String>{
  'firebaseIdToken',
  'email',
  'password',
  'confirmPassword',
  'companyName',
  'businessLicenseNo',
  'taxCode',
  'contactPerson',
  'businessAddress',
  'contactPhone',
  'businessLicenseDocument',
  'supportingDocuments',
  'acceptTerms',
};

final _supportingDocumentIndex = RegExp(
  r'^supportingDocuments\[(0|[1-9][0-9]*)\]$',
);

String? _normalizeField(String key) {
  if (_knownFields.contains(key)) return key;
  return _supportingDocumentIndex.hasMatch(key) ? 'supportingDocuments' : null;
}

String? _knownCode(Object? value) => switch (value) {
  'MSG01' ||
  'MSG02' ||
  'MSG03' ||
  'MSG04' ||
  'MSG05' ||
  'MSG06' ||
  'MSG127' ||
  'MSG157' ||
  'MSG158' ||
  'MSG159' ||
  'MSG160' ||
  'OPERATOR_TAX_CODE_INVALID' ||
  'OPERATOR_TRAVEL_LICENSE_INVALID' ||
  'MSG_TOS' ||
  'AUTH_TOKEN_MISSING' ||
  'AUTH_TOKEN_INVALID' ||
  'AUTH_EMAIL_MISMATCH' ||
  'auth.request_invalid' => value as String,
  _ => null,
};

String _messageForCode(String code, String field) => switch (code) {
  'MSG01' => 'This field is required.',
  'MSG02' => 'Enter a valid email address.',
  'MSG03' => 'An account with this email already exists.',
  'MSG04' => 'Phone number must be 10 digits starting with 0.',
  'MSG05' => 'Password does not meet the required policy.',
  'MSG06' => 'Passwords do not match. Please re-enter.',
  'MSG157' => 'Please upload the required business licence document.',
  'MSG158' =>
    'The uploaded file type is not supported or the file exceeds the size limit.',
  'MSG159' => 'This business licence number or tax code is already registered.',
  'MSG160' =>
    'An application is already pending review for this business information.',
  'OPERATOR_TAX_CODE_INVALID' => operatorTaxCodeFormatError,
  'OPERATOR_TRAVEL_LICENSE_INVALID' => operatorTravelLicenseFormatError,
  'MSG_TOS' =>
    'You must accept the Terms of Service, Privacy Policy and Partner Agreement.',
  'AUTH_TOKEN_MISSING' || 'AUTH_TOKEN_INVALID' || 'AUTH_EMAIL_MISMATCH' =>
    'Please sign in with the registration email and try again.',
  _ =>
    field == 'supportingDocuments'
        ? 'Check the supporting documents and try again.'
        : 'Check this field and try again.',
};
