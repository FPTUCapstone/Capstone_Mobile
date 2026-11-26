import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/usecases/operator_profile_use_cases.dart';

enum OperatorProfileLoadStatus { initial, loading, loaded, error }

final class OperatorProfileState extends Equatable {
  const OperatorProfileState({
    this.status = OperatorProfileLoadStatus.initial,
    this.profile,
    this.isSubmitting = false,
    this.loadError,
    this.loadErrorKind,
    this.submitError,
    this.submitErrorKind,
    this.fieldErrors = const OperatorProfileValidationErrors(),
    this.savedProfile,
  });

  final OperatorProfileLoadStatus status;
  final OperatorProfile? profile;
  final bool isSubmitting;
  final String? loadError;
  final OperatorProfileFailureKind? loadErrorKind;
  final String? submitError;
  final OperatorProfileFailureKind? submitErrorKind;
  final OperatorProfileValidationErrors fieldErrors;
  final OperatorProfile? savedProfile;

  OperatorProfileState copyWith({
    OperatorProfileLoadStatus? status,
    OperatorProfile? profile,
    bool? isSubmitting,
    String? loadError,
    bool clearLoadError = false,
    OperatorProfileFailureKind? loadErrorKind,
    bool clearLoadErrorKind = false,
    String? submitError,
    bool clearSubmitError = false,
    OperatorProfileFailureKind? submitErrorKind,
    bool clearSubmitErrorKind = false,
    OperatorProfileValidationErrors? fieldErrors,
    OperatorProfile? savedProfile,
    bool clearSavedProfile = false,
  }) => OperatorProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    loadErrorKind: clearLoadErrorKind
        ? null
        : (loadErrorKind ?? this.loadErrorKind),
    submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    submitErrorKind: clearSubmitErrorKind
        ? null
        : (submitErrorKind ?? this.submitErrorKind),
    fieldErrors: fieldErrors ?? this.fieldErrors,
    savedProfile: clearSavedProfile
        ? null
        : (savedProfile ?? this.savedProfile),
  );

  @override
  List<Object?> get props => [
    status,
    profile,
    isSubmitting,
    loadError,
    loadErrorKind,
    submitError,
    submitErrorKind,
    fieldErrors,
    savedProfile,
  ];
}

final class OperatorProfileCubit extends Cubit<OperatorProfileState> {
  OperatorProfileCubit({
    required GetOperatorProfileUseCase getProfile,
    required UpdateOperatorProfileUseCase updateProfile,
  }) : _getProfile = getProfile,
       _updateProfile = updateProfile,
       super(const OperatorProfileState());

  final GetOperatorProfileUseCase _getProfile;
  final UpdateOperatorProfileUseCase _updateProfile;
  int _loadGeneration = 0;

  void seedProfile(OperatorProfile profile) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: OperatorProfileLoadStatus.loaded,
        profile: profile,
        clearLoadError: true,
        clearLoadErrorKind: true,
      ),
    );
  }

  void applyUpdatedProfile(OperatorProfile profile) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: OperatorProfileLoadStatus.loaded,
        profile: profile,
        clearLoadError: true,
        clearLoadErrorKind: true,
      ),
    );
  }

  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        status: OperatorProfileLoadStatus.loading,
        clearLoadError: true,
        clearLoadErrorKind: true,
      ),
    );

    try {
      final profile = await _getProfile();
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: OperatorProfileLoadStatus.loaded,
          profile: profile,
          clearLoadError: true,
          clearLoadErrorKind: true,
        ),
      );
    } on OperatorProfileFailureException catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: OperatorProfileLoadStatus.error,
          loadError: error.message,
          loadErrorKind: error.kind,
        ),
      );
    } on Object {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: OperatorProfileLoadStatus.error,
          loadError: OperatorProfileMessages.systemFailure,
          loadErrorKind: OperatorProfileFailureKind.unknown,
        ),
      );
    }
  }

  Future<void> save(UpdateOperatorProfileInput input) async {
    if (isClosed || state.isSubmitting) return;
    emit(
      state.copyWith(
        isSubmitting: true,
        clearSubmitError: true,
        clearSubmitErrorKind: true,
        fieldErrors: const OperatorProfileValidationErrors(),
        clearSavedProfile: true,
      ),
    );

    try {
      final updated = await _updateProfile(input);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: OperatorProfileLoadStatus.loaded,
          profile: updated,
          isSubmitting: false,
          savedProfile: updated,
          fieldErrors: const OperatorProfileValidationErrors(),
        ),
      );
    } on OperatorProfileValidationException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(isSubmitting: false, fieldErrors: error.errors));
    } on OperatorProfileFailureException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          submitError: error.message,
          submitErrorKind: error.kind,
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          submitError: OperatorProfileMessages.systemFailure,
          submitErrorKind: OperatorProfileFailureKind.unknown,
        ),
      );
    }
  }

  void clearFieldError({
    bool businessName = false,
    bool businessDescription = false,
    bool businessAddress = false,
    bool contactPhone = false,
    bool contactEmail = false,
    bool website = false,
    bool logo = false,
  }) {
    if (isClosed || state.fieldErrors.isEmpty) return;
    emit(
      state.copyWith(
        fieldErrors: state.fieldErrors.copyWith(
          clearBusinessName: businessName,
          clearBusinessDescription: businessDescription,
          clearBusinessAddress: businessAddress,
          clearContactPhone: contactPhone,
          clearContactEmail: contactEmail,
          clearWebsite: website,
          clearLogo: logo,
          clearRemoveLogo: logo,
        ),
      ),
    );
  }
}
