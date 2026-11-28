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

  static const verificationEmailSentNotice =
      'Đã gửi email xác minh. Vui lòng kiểm tra hộp thư của bạn.';
  static const emailAlreadyVerifiedNotice =
      'Email của bạn đã được xác minh. Hãy gửi hồ sơ đăng ký ở bên dưới.';

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
            ? 'Sử dụng cùng email và mật khẩu đã tạo. Vui lòng nhập lại thông tin và chọn lại tài liệu để hoàn tất hồ sơ.'
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
              'Chưa xác định được kết quả gửi hồ sơ. Vui lòng giữ nguyên tài khoản này và chọn thao tác khôi phục phù hợp, không tạo tài khoản mới.',
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
              'Tài khoản có thể đã được tạo. Vui lòng tiếp tục với cùng email và mật khẩu này, không tạo tài khoản mới.',
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
          notice: verificationEmailSentNotice,
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
              'Đã gửi email xác minh tới tài khoản Firebase hiện có. Thao tác này không xác nhận hồ sơ đã được lưu.',
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
              'Chưa xác định được kết quả nộp hồ sơ. Không tạo tài khoản mới hoặc tự động gửi lại hồ sơ mới.',
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
            ? emailAlreadyVerifiedNotice
            : start.emailSent
            ? null
            : 'Tài khoản đã được tạo nhưng chưa thể gửi email xác minh. Vui lòng gửi lại.',
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
            : 'Hồ sơ của bạn đã được lưu nhưng chưa đồng bộ được trạng thái xác minh email. Không nộp lại; hãy dùng mục hoàn tất xác minh email.',
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
        'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng thử lại.';
    Map<String, String> fieldErrors = const {};
    if (error is ValidationFailure) {
      fieldErrors = error.fieldErrors.map(
        (key, value) => MapEntry(
          key,
          value.isEmpty ? 'Vui lòng kiểm tra trường này.' : value.first,
        ),
      );
      message = error.message;
    } else if (error is OperatorRegistrationRejected) {
      phase = preserveUncertain
          ? RegisterOperatorPhase.uncertain
          : RegisterOperatorPhase.editing;
      fieldErrors = error.fieldErrors.map(
        (key, value) => MapEntry(
          key,
          value.isEmpty ? 'Vui lòng kiểm tra trường này.' : value.first,
        ),
      );
      message = switch (error.messageCode) {
        'MSG03' => 'Email này đã được đăng ký tài khoản.',
        'MSG159' =>
          'Số giấy phép kinh doanh hoặc mã số thuế này đã được đăng ký.',
        'MSG160' =>
          'Thông tin doanh nghiệp này đã có hồ sơ đang chờ phê duyệt.',
        'MSG127' =>
          'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng thử lại.',
        _ => 'Vui lòng kiểm tra lại thông tin đăng ký và thử lại.',
      };
      if (error.messageCode == 'MSG03') {
        fieldErrors = {...fieldErrors, 'email': message};
      } else if (error.messageCode == 'MSG159') {
        fieldErrors = {...fieldErrors, 'businessLicenseNo': message};
      }
      if (preserveUncertain) {
        phase = RegisterOperatorPhase.uncertain;
        message =
            '$message Kết quả của yêu cầu trước vẫn chưa được xác nhận. Hãy xác minh tài khoản hiện có hoặc liên hệ hỗ trợ trước khi thử lại.';
      }
    } else if (error is OperatorRegistrationUncertain ||
        error is OperatorRegistrationRecoveryRequired) {
      phase = RegisterOperatorPhase.uncertain;
      canRetryOriginal = true;
      message =
          'Trạng thái đăng ký chưa được xác định. Hãy dùng tài khoản Firebase hiện có để khôi phục, không tạo tài khoản mới.';
    } else if (error is OperatorEmailNotVerified) {
      message = 'Vui lòng mở email xác minh trước rồi thử lại.';
    } else if (error is OperatorRegistrationIdentityMismatch ||
        error is AuthIdentityException &&
            error.failure == AuthIdentityFailure.invalidCredentials) {
      message =
          'Vui lòng đăng nhập bằng đúng email và mật khẩu Firebase đã dùng cho hồ sơ này.';
    } else if (error is AuthIdentityException) {
      message = switch (error.failure) {
        AuthIdentityFailure.emailAlreadyInUse =>
          'Email này đã có tài khoản Firebase. Hãy chọn tiếp tục đăng ký chưa hoàn tất.',
        AuthIdentityFailure.network =>
          'Vui lòng kiểm tra kết nối mạng và thử lại.',
        AuthIdentityFailure.tooManyRequests =>
          'Bạn thao tác quá nhiều lần. Vui lòng đợi rồi thử lại.',
        _ => 'Dịch vụ đăng ký hiện không khả dụng. Vui lòng thử lại sau.',
      };
    } else if (error is OperatorVerificationConfigurationFailure) {
      message =
          'Chức năng xác minh email chưa được cấu hình. Vui lòng liên hệ bộ phận hỗ trợ.';
    } else if (error is OperatorVerificationRejected ||
        error is OperatorVerificationUncertain) {
      message = 'Chưa thể xác nhận email của bạn lúc này. Vui lòng thử lại.';
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
        errors[name] = 'Vui lòng nhập thông tin này.';
      } else if (field(name).length > max) {
        errors[name] = 'Không được vượt quá $max ký tự.';
      }
    }

    if (step == 0) {
      final email = field('email');
      if (email.isEmpty) {
        errors['email'] = 'Vui lòng nhập thông tin này.';
      } else if (email.length > 254 ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        errors['email'] = 'Vui lòng nhập địa chỉ email hợp lệ.';
      }
      final password = values['password'] ?? '';
      if (password.isEmpty) {
        errors['password'] = 'Vui lòng nhập thông tin này.';
      } else if (password.length < 8 ||
          password.length > 72 ||
          RegExp(r'\s').hasMatch(password) ||
          !RegExp(r'[A-Z]').hasMatch(password) ||
          !RegExp(r'[a-z]').hasMatch(password) ||
          !RegExp(r'[0-9]').hasMatch(password) ||
          !RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
        errors['password'] =
            'Dùng 8–72 ký tự gồm chữ hoa, chữ thường, chữ số, ký tự đặc biệt và không có khoảng trắng.';
      }
      if ((values['confirmPassword'] ?? '').isEmpty) {
        errors['confirmPassword'] = 'Vui lòng nhập thông tin này.';
      } else if (values['confirmPassword'] != password) {
        errors['confirmPassword'] =
            'Mật khẩu xác nhận không khớp. Vui lòng nhập lại.';
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
        errors['businessAddress'] = 'Không được vượt quá 300 ký tự.';
      }
      final phone = field('contactPhone');
      if (phone.isNotEmpty && !RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
        errors['contactPhone'] =
            'Số điện thoại phải gồm 10 chữ số và bắt đầu bằng số 0.';
      }
    } else {
      if (state.businessLicence == null) {
        errors['businessLicenseDocument'] =
            'Vui lòng tải lên bản sao giấy phép kinh doanh.';
      } else if (!_validFile(state.businessLicence!)) {
        errors['businessLicenseDocument'] =
            'Chỉ hỗ trợ tệp PDF, JPG hoặc PNG, tối đa 5 MB.';
      }
      if (state.supportingDocuments.length > 5) {
        errors['supportingDocuments'] =
            'Chỉ được tải lên tối đa 5 tài liệu bổ sung.';
      } else if (state.supportingDocuments.any((file) => !_validFile(file))) {
        errors['supportingDocuments'] =
            'Chỉ hỗ trợ tệp PDF, JPG hoặc PNG, tối đa 5 MB mỗi tệp.';
      }
      if (!state.acceptedTerms) {
        errors['acceptTerms'] =
            'Vui lòng đồng ý với Điều khoản dịch vụ, Chính sách bảo mật và Thỏa thuận đối tác.';
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
