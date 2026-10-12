import 'dart:typed_data';

import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';

const operatorTaxCodeFormatError =
    'Tax Code must be 10 digits or 10 digits followed by a hyphen and 3 digits.';
const operatorTravelLicenseFormatError =
    'Travel Licence Number must follow 79-0123/2026/TCDL-GPLHQT or 01-0456/2025/SDL-GPLHND.';

final _operatorTaxCodePattern = RegExp(r'^[0-9]{10}(-[0-9]{3})?$');
final _operatorTravelLicensePattern = RegExp(
  r'^[0-9]{2}-[0-9]+/[0-9]{4}/(TCDL-GPLHQT|SDL-GPLHND)$',
);

bool isValidOperatorTaxCode(String value) =>
    _operatorTaxCodePattern.hasMatch(value.trim());

bool isValidOperatorTravelLicense(String value) =>
    _operatorTravelLicensePattern.hasMatch(value.trim());

final class OperatorVerificationConfigurationFailure implements Exception {
  const OperatorVerificationConfigurationFailure();
}

final class OperatorRegistrationRecoveryRequired implements Exception {
  const OperatorRegistrationRecoveryRequired();
}

final class OperatorEmailNotVerified implements Exception {
  const OperatorEmailNotVerified();
}

final class RegisterTourOperator {
  RegisterTourOperator({
    required TourOperatorRegistrationRepository repository,
    required OperatorRegistrationIdentityService identityService,
    required Uri Function() verificationContinueUrl,
  }) : _repository = repository,
       _identityService = identityService,
       _verificationContinueUrl = verificationContinueUrl;

  final TourOperatorRegistrationRepository _repository;
  final OperatorRegistrationIdentityService _identityService;
  final Uri Function() _verificationContinueUrl;
  _PendingOperatorRegistration? _pending;
  String? _committedIdentityId;

  Uri _continueUrl() {
    final Uri continueUrl;
    try {
      continueUrl = _verificationContinueUrl();
    } on StateError {
      throw const OperatorVerificationConfigurationFailure();
    } on FormatException {
      throw const OperatorVerificationConfigurationFailure();
    }
    if (!continueUrl.hasScheme || continueUrl.host.isEmpty) {
      throw const OperatorVerificationConfigurationFailure();
    }
    return continueUrl;
  }

  Future<OperatorVerificationStart> call(
    TourOperatorRegistration registration,
  ) async {
    if (_pending != null || _committedIdentityId != null) {
      throw const OperatorRegistrationRecoveryRequired();
    }
    final normalized = _validatedRegistration(registration);
    final continueUrl = _continueUrl();

    final OperatorCreatedIdentity created;
    try {
      created = await _identityService.create(
        email: normalized.email,
        password: normalized.password,
      );
    } on OperatorIdentityCreationUncertain catch (error) {
      _pending = _PendingOperatorRegistration(
        normalized,
        error.userId,
        unknownOutcome: false,
      );
      rethrow;
    }
    _pending = _PendingOperatorRegistration(
      normalized,
      created.userId,
      unknownOutcome: false,
    );
    return _sendVerification(created.userId, continueUrl);
  }

  Future<OperatorVerificationStart> _sendVerification(
    String userId,
    Uri continueUrl,
  ) async {
    try {
      await _identityService.sendVerificationEmailFor(userId, continueUrl);
      return const OperatorVerificationStart(
        emailSent: true,
        alreadyVerified: false,
      );
    } catch (_) {
      // The Firebase account exists; keep it so the applicant can resend.
      return const OperatorVerificationStart(
        emailSent: false,
        alreadyVerified: false,
      );
    }
  }

  /// A verified Firebase identity is required before creating the BE application.
  Future<TourOperatorRegistrationOutcome> submitVerifiedApplication() async {
    final pending = _pending;
    if (pending == null || pending.unknownOutcome) {
      throw const OperatorRegistrationRecoveryRequired();
    }
    final token = await _identityService.verifiedIdTokenFor(
      pending.registration.email,
    );
    if (token == null) throw const OperatorEmailNotVerified();
    try {
      final result = await _repository.register(pending.registration, token);
      return await _afterCommit(result, pending.identityId, token);
    } on OperatorRegistrationUncertain {
      _pending = _PendingOperatorRegistration(
        pending.registration,
        pending.identityId,
      );
      rethrow;
    }
  }

  /// Explicit retry after an unknown POST outcome, preserving the original form.
  Future<TourOperatorRegistrationOutcome> retryUnknownOutcome() async {
    final pending = _pending;
    if (pending == null || !pending.unknownOutcome) {
      throw const OperatorRegistrationRecoveryRequired();
    }
    final recovered = await _identityService.recover(
      email: pending.registration.email,
      password: pending.registration.password,
    );
    if (recovered.userId != pending.identityId) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    final token = await _identityService.verifiedIdTokenFor(
      pending.registration.email,
    );
    if (token == null) throw const OperatorEmailNotVerified();
    final result = await _repository.register(pending.registration, token);
    return _afterCommit(result, recovered.userId, token);
  }

  /// Explicit recovery after restart; no Firebase create or automatic POST.
  Future<OperatorVerificationStart> retryWithExistingIdentity(
    TourOperatorRegistration registration,
  ) async {
    if (_committedIdentityId != null || _pending?.unknownOutcome == true) {
      throw const OperatorRegistrationRecoveryRequired();
    }
    final normalized = _validatedRegistration(registration);
    final continueUrl = _continueUrl();
    final recovered = await _identityService.recover(
      email: normalized.email,
      password: normalized.password,
    );
    if (_pending != null && _pending!.identityId != recovered.userId) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    _pending = _PendingOperatorRegistration(
      normalized,
      recovered.userId,
      unknownOutcome: false,
    );
    final verified = await _identityService.verifiedIdTokenFor(
      normalized.email,
    );
    if (verified != null) {
      return const OperatorVerificationStart(
        emailSent: false,
        alreadyVerified: true,
      );
    }
    return _sendVerification(recovered.userId, continueUrl);
  }

  Future<TourOperatorRegistrationOutcome> _afterCommit(
    TourOperatorRegistrationResult result,
    String identityId,
    String verifiedToken,
  ) async {
    _pending = null;
    _committedIdentityId = identityId;
    try {
      await _repository.confirmVerifiedEmail(verifiedToken);
      return TourOperatorRegistrationOutcome(
        registration: result,
        verificationSynced: true,
      );
    } catch (_) {
      // BE committed the application. Never submit it again just to sync the marker.
      return TourOperatorRegistrationOutcome(
        registration: result,
        verificationSynced: false,
      );
    }
  }

  /// Sends no registration POST.
  Future<void> resendVerificationEmail() async {
    final identityId = _pending?.identityId;
    if (identityId == null) throw const OperatorRegistrationRecoveryRequired();
    await _identityService.sendVerificationEmailFor(identityId, _continueUrl());
  }

  /// Explicit recovery after restart; this sends no registration request.
  /// Email delivery is not proof that the BE registration committed.
  Future<void> sendRecoveryVerificationEmail({
    required String email,
    required String password,
  }) async {
    final continueUrl = _continueUrl();
    final recovered = await _identityService.recover(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (_pending != null && _pending!.identityId != recovered.userId) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    await _identityService.sendVerificationEmailFor(
      recovered.userId,
      continueUrl,
    );
  }

  /// Uses verified Firebase evidence and the BE Web verifier, never a session API.
  Future<void> confirmVerifiedEmail(String email, {String? password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    if (password != null) {
      await _identityService.recover(
        email: normalizedEmail,
        password: password,
      );
    }
    final token = await _identityService.verifiedIdTokenFor(normalizedEmail);
    if (token == null) throw const OperatorEmailNotVerified();
    await _repository.confirmVerifiedEmail(token);
  }

  TourOperatorRegistration _validatedRegistration(
    TourOperatorRegistration input,
  ) {
    final errors = <String, List<String>>{};
    void error(String field, String message) => errors[field] = [message];
    void requiredText(String field, String value, int maxLength) {
      if (value.trim().isEmpty) {
        error(field, 'This field is required.');
      } else if (value.length > maxLength) {
        error(field, 'Must be $maxLength characters or fewer.');
      }
    }

    final email = input.email.trim().toLowerCase();
    if (email.isEmpty) {
      error('email', 'This field is required.');
    } else if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      error('email', 'Enter a valid email address.');
    }
    final password = input.password;
    if (password.isEmpty) {
      error('password', 'This field is required.');
    } else if (password.length < 8 ||
        password.length > 72 ||
        RegExp(r'\s').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
      error(
        'password',
        'Password must be 8–72 characters, contain uppercase, lowercase, number and special character, and no whitespace.',
      );
    }
    if (input.confirmPassword.isEmpty) {
      error('confirmPassword', 'This field is required.');
    } else if (input.confirmPassword != password) {
      error('confirmPassword', 'Passwords do not match. Please re-enter.');
    }
    requiredText('companyName', input.companyName, 200);
    requiredText('businessLicenseNo', input.businessLicenseNo, 100);
    requiredText('taxCode', input.taxCode, 50);
    if (!errors.containsKey('businessLicenseNo') &&
        !isValidOperatorTravelLicense(input.businessLicenseNo)) {
      error('businessLicenseNo', operatorTravelLicenseFormatError);
    }
    if (!errors.containsKey('taxCode') &&
        !isValidOperatorTaxCode(input.taxCode)) {
      error('taxCode', operatorTaxCodeFormatError);
    }
    requiredText('contactPerson', input.contactPerson, 150);
    final address = input.businessAddress?.trim();
    if (address != null && address.length > 300) {
      error('businessAddress', 'Must be 300 characters or fewer.');
    }
    final phone = input.contactPhone?.trim();
    if (phone != null &&
        phone.isNotEmpty &&
        !RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
      error('contactPhone', 'Phone number must be 10 digits starting with 0.');
    }
    if (input.businessLicenseDocument == null) {
      error(
        'businessLicenseDocument',
        'Please upload the required business licence document.',
      );
    } else if (!_validDocument(input.businessLicenseDocument!)) {
      error(
        'businessLicenseDocument',
        'The uploaded file type is not supported or the file exceeds the size limit.',
      );
    }
    if (input.supportingDocuments.length > 5 ||
        input.supportingDocuments.any((file) => !_validDocument(file))) {
      error(
        'supportingDocuments',
        input.supportingDocuments.length > 5
            ? 'No more than 5 supporting documents are allowed.'
            : 'The uploaded file type is not supported or the file exceeds the size limit.',
      );
    }
    if (!input.acceptedTerms) {
      error(
        'acceptTerms',
        'You must accept the Terms of Service, Privacy Policy and Partner Agreement.',
      );
    }
    if (errors.isNotEmpty) {
      throw ValidationFailure(
        'Check your registration details.',
        fieldErrors: errors,
      );
    }
    return TourOperatorRegistration(
      email: email,
      password: password,
      confirmPassword: input.confirmPassword,
      companyName: input.companyName.trim(),
      businessLicenseNo: input.businessLicenseNo.trim(),
      taxCode: input.taxCode.trim(),
      contactPerson: input.contactPerson.trim(),
      businessAddress: address?.isEmpty == true ? null : address,
      contactPhone: phone?.isEmpty == true ? null : phone,
      businessLicenseDocument: input.businessLicenseDocument == null
          ? null
          : _copyDocument(input.businessLicenseDocument!),
      supportingDocuments: List.unmodifiable(
        input.supportingDocuments.map(_copyDocument),
      ),
      acceptedTerms: input.acceptedTerms,
    );
  }

  OperatorDocumentUpload _copyDocument(OperatorDocumentUpload source) =>
      OperatorDocumentUpload(
        fileName: source.fileName,
        contentType: source.contentType,
        bytes: Uint8List.fromList(source.bytes),
      );

  bool _validDocument(OperatorDocumentUpload document) {
    if (document.fileName.trim().isEmpty ||
        document.bytes.isEmpty ||
        document.bytes.length > 5 * 1024 * 1024) {
      return false;
    }
    final extension = document.fileName.toLowerCase().split('.').last;
    final mime = document.contentType.toLowerCase();
    return switch (mime) {
      'application/pdf' => extension == 'pdf',
      'image/jpeg' => extension == 'jpg' || extension == 'jpeg',
      'image/png' => extension == 'png',
      _ => false,
    };
  }
}

final class _PendingOperatorRegistration {
  const _PendingOperatorRegistration(
    this.registration,
    this.identityId, {
    this.unknownOutcome = true,
  });

  final TourOperatorRegistration registration;
  final String identityId;
  final bool unknownOutcome;
}
