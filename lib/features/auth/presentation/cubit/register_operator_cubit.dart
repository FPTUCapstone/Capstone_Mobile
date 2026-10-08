import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';

enum RegisterOperatorPhase {
  editing,
  awaitingVerification,
  uncertain,
  submitted,
}

final class RegisterOperatorState {
  const RegisterOperatorState({
    this.step = 0,
    this.values = const {},
    this.errors = const {},
    this.businessLicence,
    this.supportingDocuments = const [],
    this.acceptedTerms = false,
    this.phase = RegisterOperatorPhase.editing,
    this.isBusy = false,
    this.notice,
    this.outcome,
    this.emailSent = false,
    this.alreadyVerified = false,
    this.canRetryOriginal = false,
    this.resumeExistingIdentity = false,
  });

  final int step;
  final Map<String, String> values;
  final Map<String, String> errors;
  final OperatorDocumentUpload? businessLicence;
  final List<OperatorDocumentUpload> supportingDocuments;
  final bool acceptedTerms;
  final RegisterOperatorPhase phase;
  final bool isBusy;
  final String? notice;
  final TourOperatorRegistrationOutcome? outcome;
  final bool emailSent;
  final bool alreadyVerified;
  final bool canRetryOriginal;
  final bool resumeExistingIdentity;

  RegisterOperatorState copyWith({
    int? step,
    Map<String, String>? values,
    Map<String, String>? errors,
    Object? businessLicence = _unchanged,
    List<OperatorDocumentUpload>? supportingDocuments,
    bool? acceptedTerms,
    RegisterOperatorPhase? phase,
    bool? isBusy,
    Object? notice = _unchanged,
    Object? outcome = _unchanged,
    bool? emailSent,
    bool? alreadyVerified,
    bool? canRetryOriginal,
    bool? resumeExistingIdentity,
  }) => RegisterOperatorState(
    step: step ?? this.step,
    values: values ?? this.values,
    errors: errors ?? this.errors,
    businessLicence: identical(businessLicence, _unchanged)
        ? this.businessLicence
        : businessLicence as OperatorDocumentUpload?,
    supportingDocuments: supportingDocuments ?? this.supportingDocuments,
    acceptedTerms: acceptedTerms ?? this.acceptedTerms,
    phase: phase ?? this.phase,
    isBusy: isBusy ?? this.isBusy,
    notice: identical(notice, _unchanged) ? this.notice : notice as String?,
    outcome: identical(outcome, _unchanged)
        ? this.outcome
        : outcome as TourOperatorRegistrationOutcome?,
    emailSent: emailSent ?? this.emailSent,
    alreadyVerified: alreadyVerified ?? this.alreadyVerified,
    canRetryOriginal: canRetryOriginal ?? this.canRetryOriginal,
    resumeExistingIdentity:
        resumeExistingIdentity ?? this.resumeExistingIdentity,
  );
}

const _unchanged = Object();

final class RegisterOperatorCubit extends Cubit<RegisterOperatorState> {
  RegisterOperatorCubit(this._register) : super(const RegisterOperatorState());

  final RegisterTourOperator _register;

  bool get _canEdit =>
      !state.isBusy && state.phase == RegisterOperatorPhase.editing;

  void updateField(String field, String value) {
    if (!_canEdit) return;
    final errors = Map<String, String>.of(state.errors)..remove(field);
    emit(
      state.copyWith(
        values: Map.unmodifiable({...state.values, field: value}),
        errors: Map.unmodifiable(errors),
        notice: null,
      ),
    );
  }

  void setBusinessLicence(OperatorDocumentUpload? document) {
    if (!_canEdit) return;
    final errors = Map<String, String>.of(state.errors)
      ..remove('businessLicenseDocument');
    emit(
      state.copyWith(
        businessLicence: document,
        errors: Map.unmodifiable(errors),
      ),
    );
  }

  void setSupportingDocuments(List<OperatorDocumentUpload> documents) {
    if (!_canEdit) return;
    final errors = Map<String, String>.of(state.errors)
      ..remove('supportingDocuments');
    emit(
      state.copyWith(
        supportingDocuments: List.unmodifiable(documents),
        errors: Map.unmodifiable(errors),
      ),
    );
  }

  void setAcceptedTerms(bool accepted) {
    if (!_canEdit) return;
    final errors = Map<String, String>.of(state.errors)..remove('acceptTerms');
    emit(
      state.copyWith(acceptedTerms: accepted, errors: Map.unmodifiable(errors)),
    );
  }

  void setResumeExistingIdentity(bool value) {
    if (!_canEdit) return;
    emit(
      state.copyWith(
        resumeExistingIdentity: value,
        notice: value
            ? 'Use the same email and password. Re-enter your details and select the documents again to finish your application.'
            : null,
      ),
    );
  }

  bool next() {
    if (!_canEdit || state.step >= 2) return false;
    final errors = _validateStep(state.step);
    if (errors.isNotEmpty) {
      emit(state.copyWith(errors: Map.unmodifiable(errors)));
      return false;
    }
    emit(state.copyWith(step: state.step + 1, errors: const {}));
    return true;
  }

  void back() {
    if (!_canEdit || state.step == 0) return;
    emit(state.copyWith(step: state.step - 1, errors: const {}));
  }

  Future<void> submit() async {
    if (!_canEdit || state.step != 2) return;
    final errors = _validateStep(2);
    if (errors.isNotEmpty) {
      emit(state.copyWith(errors: Map.unmodifiable(errors)));
      return;
    }
    final registration = _registration();
    emit(state.copyWith(isBusy: true, notice: null, errors: const {}));
    try {
      final start = state.resumeExistingIdentity
          ? await _register.retryWithExistingIdentity(registration)
          : await _register(registration);
      if (isClosed) return;
      _recordVerificationStart(start);
    } on OperatorRegistrationUncertain {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: RegisterOperatorPhase.uncertain,
          isBusy: false,
          canRetryOriginal: true,
          notice:
              'The request outcome is unknown. Keep this account and choose an explicit recovery action. Do not create another account.',
        ),
      );
    } on OperatorIdentityCreationUncertain {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: RegisterOperatorPhase.editing,
          isBusy: false,
          resumeExistingIdentity: true,
          notice:
              'The account may have been created. Continue with this same email and password; do not create another account.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _recordError(error);
    }
  }

  Future<void> retryUnknownOutcome() async {
    if (state.isBusy ||
        state.phase != RegisterOperatorPhase.uncertain ||
        !state.canRetryOriginal) {
      return;
    }
    emit(state.copyWith(isBusy: true, notice: null));
    try {
      final outcome = await _register.retryUnknownOutcome();
      if (isClosed) return;
      _recordSuccess(outcome);
    } catch (error) {
      if (isClosed) return;
      _recordError(error, preservePhase: true, preserveUncertain: true);
    }
  }

  Future<void> retryWithExistingIdentity() async {
    if (state.isBusy ||
        state.phase != RegisterOperatorPhase.editing ||
        state.step != 2) {
      return;
    }
    final errors = <String, String>{};
    for (var step = 0; step < 3; step++) {
      errors.addAll(_validateStep(step));
    }
    if (errors.isNotEmpty) {
      final firstStep = errors.keys.any(_accountFields.contains)
          ? 0
          : errors.keys.any(_companyFields.contains)
          ? 1
          : 2;
      emit(state.copyWith(step: firstStep, errors: Map.unmodifiable(errors)));
      return;
    }
    emit(state.copyWith(isBusy: true, notice: null));
    try {
      final start = await _register.retryWithExistingIdentity(_registration());
      if (isClosed) return;
      _recordVerificationStart(start);
    } catch (error) {
      if (isClosed) return;
      _recordError(error);
    }
  }

  Future<void> resendEmail() async {
    if (state.isBusy ||
        state.phase != RegisterOperatorPhase.awaitingVerification) {
      return;
    }
    emit(state.copyWith(isBusy: true, notice: null));
    try {
      await _register.resendVerificationEmail();
      if (isClosed) return;
      emit(
        state.copyWith(
          isBusy: false,
          emailSent: true,
          notice: 'Verification email sent. Please check your inbox.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _recordError(error, preservePhase: true);
    }
  }

  Future<void> sendRecoveryVerificationEmail() async {
    if (state.isBusy || state.phase == RegisterOperatorPhase.submitted) {
      return;
    }
    emit(state.copyWith(isBusy: true, notice: null));
    try {
      await _register.sendRecoveryVerificationEmail(
        email: state.values['email'] ?? '',
        password: state.values['password'] ?? '',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isBusy: false,
          notice:
              'Verification email sent to the existing Firebase account. This does not confirm that the application was saved.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _recordError(error, preservePhase: true, preserveUncertain: true);
    }
  }

  Future<void> confirmVerifiedEmail() async {
    if (state.isBusy ||
        state.phase != RegisterOperatorPhase.awaitingVerification) {
      return;
    }
    emit(state.copyWith(isBusy: true, notice: null));
    try {
      final outcome = await _register.submitVerifiedApplication();
      if (isClosed) return;
      _recordSuccess(outcome);
    } on OperatorRegistrationUncertain {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: RegisterOperatorPhase.uncertain,
          isBusy: false,
          canRetryOriginal: true,
          notice:
              'The application submission outcome is unknown. Do not create another account or submit a new application automatically.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _recordError(error, preservePhase: error is OperatorEmailNotVerified);
    }
  }

  void _recordVerificationStart(OperatorVerificationStart start) {
    emit(
      state.copyWith(
        isBusy: false,
        phase: RegisterOperatorPhase.awaitingVerification,
        emailSent: start.emailSent,
        alreadyVerified: start.alreadyVerified,
        canRetryOriginal: false,
        errors: const {},
        notice: start.alreadyVerified
            ? 'Your email is already verified. Submit the application below.'
            : start.emailSent
            ? null
            : 'The account was created, but the verification email could not be sent. Please resend it.',
      ),
    );
  }

  void _recordSuccess(TourOperatorRegistrationOutcome outcome) {
    emit(
      state.copyWith(
        isBusy: false,
        phase: RegisterOperatorPhase.submitted,
        outcome: outcome,
        emailSent: false,
        canRetryOriginal: false,
        errors: const {},
        notice: outcome.verificationSynced
            ? null
            : 'Your application was saved, but email confirmation could not be synchronized. Do not submit again; use the existing-account recovery action.',
      ),
    );
  }

  void _recordError(
    Object error, {
    bool preserveUncertain = false,
    bool preservePhase = false,
  }) {
    var phase = preservePhase || preserveUncertain
        ? state.phase
        : RegisterOperatorPhase.editing;
    var canRetryOriginal = state.canRetryOriginal;
    var message =
        'TripMate is temporarily unable to process your request. Please try again.';
    Map<String, String> fieldErrors = const {};
    if (error is ValidationFailure) {
      fieldErrors = error.fieldErrors.map(
        (key, value) =>
            MapEntry(key, value.isEmpty ? 'Check this field.' : value.first),
      );
      message = error.message;
    } else if (error is OperatorRegistrationRejected) {
      phase = preserveUncertain
          ? RegisterOperatorPhase.uncertain
          : RegisterOperatorPhase.editing;
      fieldErrors = error.fieldErrors.map(
        (key, value) =>
            MapEntry(key, value.isEmpty ? 'Check this field.' : value.first),
      );
      message = switch (error.messageCode) {
        'MSG03' => 'An account with this email already exists.',
        'MSG159' =>
          'This business licence number or tax code is already registered.',
        'MSG160' =>
          'An application is already pending review for this business information.',
        'MSG127' =>
          'TripMate is temporarily unable to process your request. Please try again.',
        _ => 'Check your registration details and try again.',
      };
      if (error.messageCode == 'MSG03') {
        fieldErrors = {...fieldErrors, 'email': message};
      } else if (error.messageCode == 'MSG159') {
        fieldErrors = {...fieldErrors, 'businessLicenseNo': message};
      }
      if (preserveUncertain) {
        phase = RegisterOperatorPhase.uncertain;
        message =
            '$message The earlier request\'s outcome remains unconfirmed. Verify the existing account or contact support before trying again.';
      }
    } else if (error is OperatorRegistrationUncertain ||
        error is OperatorRegistrationRecoveryRequired) {
      phase = RegisterOperatorPhase.uncertain;
      canRetryOriginal = true;
      message =
          'The registration status is uncertain. Use your existing Firebase account to recover; do not create another account.';
    } else if (error is OperatorEmailNotVerified) {
      message = 'Please open your verification email first, then try again.';
    } else if (error is OperatorRegistrationIdentityMismatch ||
        error is AuthIdentityException &&
            error.failure == AuthIdentityFailure.invalidCredentials) {
      message =
          'Sign in with the same Firebase email and password used for this application.';
    } else if (error is AuthIdentityException) {
      message = switch (error.failure) {
        AuthIdentityFailure.emailAlreadyInUse =>
          'A Firebase account with this email exists. Use existing-account recovery.',
        AuthIdentityFailure.network =>
          'Please check your connection and try again.',
        AuthIdentityFailure.tooManyRequests =>
          'Too many attempts. Please wait before trying again.',
        _ => 'The registration service is unavailable. Please try again later.',
      };
    } else if (error is OperatorVerificationConfigurationFailure) {
      message = 'Email verification is not configured. Please contact support.';
    } else if (error is OperatorVerificationRejected ||
        error is OperatorVerificationUncertain) {
      message = 'We could not confirm your email yet. Please try again.';
    }
    final firstStep = fieldErrors.keys.any(_accountFields.contains)
        ? 0
        : fieldErrors.keys.any(_companyFields.contains)
        ? 1
        : state.step;
    emit(
      state.copyWith(
        step: firstStep,
        isBusy: false,
        phase: phase,
        canRetryOriginal: canRetryOriginal,
        resumeExistingIdentity: error is OperatorRegistrationRejected
            ? true
            : state.resumeExistingIdentity,
        notice: message,
        errors: Map.unmodifiable(fieldErrors),
      ),
    );
  }

  TourOperatorRegistration _registration() => TourOperatorRegistration(
    email: state.values['email'] ?? '',
    password: state.values['password'] ?? '',
    confirmPassword: state.values['confirmPassword'] ?? '',
    companyName: state.values['companyName'] ?? '',
    businessLicenseNo: state.values['businessLicenseNo'] ?? '',
    taxCode: state.values['taxCode'] ?? '',
    contactPerson: state.values['contactPerson'] ?? '',
    businessAddress: state.values['businessAddress'],
    contactPhone: state.values['contactPhone'],
    businessLicenseDocument: state.businessLicence,
    supportingDocuments: state.supportingDocuments,
    acceptedTerms: state.acceptedTerms,
  );

  Map<String, String> _validateStep(int step) {
    final values = state.values;
    final errors = <String, String>{};
    String field(String name) => values[name]?.trim() ?? '';
    void required(String name, int max) {
      if (field(name).isEmpty) {
        errors[name] = 'This field is required.';
      } else if (field(name).length > max) {
        errors[name] = 'Must be $max characters or fewer.';
      }
    }

    if (step == 0) {
      final email = field('email');
      if (email.isEmpty) {
        errors['email'] = 'This field is required.';
      } else if (email.length > 254 ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        errors['email'] = 'Enter a valid email address.';
      }
      final password = values['password'] ?? '';
      if (password.isEmpty) {
        errors['password'] = 'This field is required.';
      } else if (password.length < 8 ||
          password.length > 72 ||
          RegExp(r'\s').hasMatch(password) ||
          !RegExp(r'[A-Z]').hasMatch(password) ||
          !RegExp(r'[a-z]').hasMatch(password) ||
          !RegExp(r'[0-9]').hasMatch(password) ||
          !RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
        errors['password'] =
            'Use 8–72 characters with uppercase, lowercase, number, special character and no spaces.';
      }
      if ((values['confirmPassword'] ?? '').isEmpty) {
        errors['confirmPassword'] = 'This field is required.';
      } else if (values['confirmPassword'] != password) {
        errors['confirmPassword'] = 'Passwords do not match. Please re-enter.';
      }
    } else if (step == 1) {
      required('companyName', 200);
      required('businessLicenseNo', 100);
      required('taxCode', 50);
      if (!errors.containsKey('businessLicenseNo') &&
          !isValidOperatorTravelLicense(field('businessLicenseNo'))) {
        errors['businessLicenseNo'] = operatorTravelLicenseFormatError;
      }
      if (!errors.containsKey('taxCode') &&
          !isValidOperatorTaxCode(field('taxCode'))) {
        errors['taxCode'] = operatorTaxCodeFormatError;
      }
      required('contactPerson', 150);
      if (field('businessAddress').length > 300) {
        errors['businessAddress'] = 'Must be 300 characters or fewer.';
      }
      final phone = field('contactPhone');
      if (phone.isNotEmpty && !RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
        errors['contactPhone'] =
            'Phone number must be 10 digits starting with 0.';
      }
    } else {
      if (state.businessLicence == null) {
        errors['businessLicenseDocument'] =
            'Please upload the required business licence document.';
      } else if (!_validFile(state.businessLicence!)) {
        errors['businessLicenseDocument'] = 'Use PDF, JPG or PNG, up to 5 MB.';
      }
      if (state.supportingDocuments.length > 5) {
        errors['supportingDocuments'] =
            'No more than 5 supporting documents are allowed.';
      } else if (state.supportingDocuments.any((file) => !_validFile(file))) {
        errors['supportingDocuments'] =
            'Use PDF, JPG or PNG, up to 5 MB per file.';
      }
      if (!state.acceptedTerms) {
        errors['acceptTerms'] =
            'Accept the Terms of Service, Privacy Policy and Partner Agreement.';
      }
    }
    return errors;
  }

  bool _validFile(OperatorDocumentUpload file) {
    if (file.bytes.isEmpty || file.bytes.length > 5 * 1024 * 1024) return false;
    final extension = file.fileName.toLowerCase().split('.').last;
    return switch (file.contentType.toLowerCase()) {
      'application/pdf' => extension == 'pdf',
      'image/jpeg' => extension == 'jpg' || extension == 'jpeg',
      'image/png' => extension == 'png',
      _ => false,
    };
  }
}

const _accountFields = {'email', 'password', 'confirmPassword'};
const _companyFields = {
  'companyName',
  'businessLicenseNo',
  'taxCode',
  'contactPerson',
  'businessAddress',
  'contactPhone',
};
