import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/fetch_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/resubmit_operator_application.dart';

enum OperatorApplicationStatus {
  loading,
  rejected,
  pending,
  approved,
  unresolved,
}

final class OperatorApplicationState extends Equatable {
  const OperatorApplicationState({
    required this.status,
    this.application,
    this.isSubmitting = false,
    this.fieldErrors = const {},
    this.errorMessage,
    this.successMessage,
  });

  const OperatorApplicationState.loading()
    : this(status: OperatorApplicationStatus.loading);

  final OperatorApplicationStatus status;
  final OperatorApplication? application;
  final bool isSubmitting;
  final Map<String, String> fieldErrors;
  final String? errorMessage;
  final String? successMessage;

  OperatorApplicationState copyWith({
    OperatorApplicationStatus? status,
    OperatorApplication? application,
    bool? isSubmitting,
    Map<String, String>? fieldErrors,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
  }) => OperatorApplicationState(
    status: status ?? this.status,
    application: application ?? this.application,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    successMessage: successMessage ?? this.successMessage,
  );

  @override
  List<Object?> get props => [
    status,
    application,
    isSubmitting,
    fieldErrors,
    errorMessage,
    successMessage,
  ];
}

final class OperatorApplicationCubit extends Cubit<OperatorApplicationState> {
  OperatorApplicationCubit(this._fetchApplication, this._resubmitApplication)
    : super(const OperatorApplicationState.loading());

  final FetchOperatorApplication _fetchApplication;
  final ResubmitOperatorApplicationUseCase _resubmitApplication;

  Future<void> loadApplication() async {
    emit(const OperatorApplicationState.loading());
    try {
      final application = await _fetchApplication();
      emit(
        OperatorApplicationState(
          status: _status(application.approvalStatus),
          application: application,
        ),
      );
    } on OperatorApplicationFailure catch (error) {
      emit(
        OperatorApplicationState(
          status: OperatorApplicationStatus.unresolved,
          errorMessage: _message(error.code),
        ),
      );
    }
  }

  Future<bool> resubmit(ResubmitOperatorApplication input) async {
    if (state.isSubmitting ||
        state.status != OperatorApplicationStatus.rejected) {
      return false;
    }
    emit(
      state.copyWith(
        isSubmitting: true,
        fieldErrors: const {},
        clearError: true,
      ),
    );
    try {
      await _resubmitApplication(input);
      final refreshed = await _fetchApplication();
      emit(
        OperatorApplicationState(
          status: _status(refreshed.approvalStatus),
          application: refreshed,
          successMessage: _message('MSG162'),
        ),
      );
      return true;
    } on OperatorApplicationFailure catch (error) {
      if (error.code == 'MSG161') {
        await loadApplication();
        return false;
      }
      final mappedFieldErrors = <String, String>{};
      for (final entry in error.fieldErrors.entries) {
        mappedFieldErrors[entry.key] = _fieldErrorMessage(
          entry.key,
          entry.value,
        );
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          fieldErrors: mappedFieldErrors,
          errorMessage: _message(error.code),
        ),
      );
      return false;
    }
  }

  static String _fieldErrorMessage(String field, String code) {
    if (code == 'MSG159') {
      if (field == 'taxCode') {
        return 'This tax code is already registered.';
      }
      if (field == 'businessLicenseNo') {
        return 'This business licence number is already registered.';
      }
      return 'This business licence number or tax code is already registered.';
    }
    return _message(code);
  }

  static OperatorApplicationStatus _status(String value) => switch (value) {
    'Rejected' => OperatorApplicationStatus.rejected,
    'PendingApproval' => OperatorApplicationStatus.pending,
    'Approved' => OperatorApplicationStatus.approved,
    _ => OperatorApplicationStatus.unresolved,
  };

  static String _message(String code) => switch (code) {
    'MSG01' => 'This field is required.',
    'MSG157' => 'Please upload the required business licence document.',
    'MSG158' =>
      'The uploaded file type is not supported or the file exceeds the size limit.',
    'MSG159' =>
      'This business licence number or tax code is already registered.',
    'MSG161' => 'Only rejected applications can be resubmitted.',
    'MSG162' =>
      'Application resubmitted successfully. It is now pending administrator review.',
    'UNAUTHENTICATED' => 'Your session has expired. Please sign in again.',
    _ =>
      'TripMate is temporarily unable to process your request. Please check your connection and try again.',
  };
}
