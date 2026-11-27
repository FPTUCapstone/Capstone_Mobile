import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/usecases/operator_profile_use_cases.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_profile_cubit.dart';

final class _FakeRepo implements OperatorProfileRepository {
  OperatorProfile? profileToReturn;
  Object? errorToThrow;
  int updateCalls = 0;

  @override
  Future<OperatorProfile> getProfile() async {
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn!;
  }

  @override
  Future<OperatorProfile> updateProfile(
    UpdateOperatorProfileInput input,
  ) async {
    updateCalls += 1;
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn!;
  }
}

const _sampleProfile = OperatorProfile(
  userId: 12,
  businessName: 'Sun Tours',
  businessDescription: 'Family tours',
  businessAddress: '1 Beach Rd',
  contactPhone: '0901234567',
  contactEmail: 'hello@suntours.vn',
  website: 'https://suntours.vn',
  businessLicenceNumber: '79-1234/2026/TCDL-GPLHQT',
  taxCode: '0312345678',
  approvalStatus: 'Approved',
  accountEmail: 'owner@suntours.vn',
);

void main() {
  group('OperatorProfileCubit', () {
    late _FakeRepo repo;

    setUp(() {
      repo = _FakeRepo()..profileToReturn = _sampleProfile;
    });

    blocTest<OperatorProfileCubit, OperatorProfileState>(
      'load() emits loading then loaded with profile',
      build: () => OperatorProfileCubit(
        getProfile: GetOperatorProfileUseCase(repo),
        updateProfile: UpdateOperatorProfileUseCase(repo),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const OperatorProfileState(status: OperatorProfileLoadStatus.loading),
        const OperatorProfileState(
          status: OperatorProfileLoadStatus.loaded,
          profile: _sampleProfile,
        ),
      ],
    );

    blocTest<OperatorProfileCubit, OperatorProfileState>(
      'load() emits error with MSG126 on 403 forbidden',
      setUp: () {
        repo.errorToThrow = const OperatorProfileFailureException(
          kind: OperatorProfileFailureKind.forbidden,
          message: OperatorProfileMessages.notApprovedOperator,
        );
      },
      build: () => OperatorProfileCubit(
        getProfile: GetOperatorProfileUseCase(repo),
        updateProfile: UpdateOperatorProfileUseCase(repo),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const OperatorProfileState(status: OperatorProfileLoadStatus.loading),
        const OperatorProfileState(
          status: OperatorProfileLoadStatus.error,
          loadError: OperatorProfileMessages.notApprovedOperator,
          loadErrorKind: OperatorProfileFailureKind.forbidden,
        ),
      ],
    );

    blocTest<OperatorProfileCubit, OperatorProfileState>(
      'save() emits validation errors locally without calling repository when invalid',
      build: () => OperatorProfileCubit(
        getProfile: GetOperatorProfileUseCase(repo),
        updateProfile: UpdateOperatorProfileUseCase(repo),
      ),
      act: (cubit) => cubit.save(
        const UpdateOperatorProfileInput(
          businessName: '',
          businessDescription: '',
          businessAddress: '',
          contactPhone: 'bad-phone',
          contactEmail: '',
          website: 'no-scheme.vn',
        ),
      ),
      verify: (_) => expect(repo.updateCalls, 0),
      expect: () => [
        const OperatorProfileState(isSubmitting: true),
        const OperatorProfileState(
          isSubmitting: false,
          fieldErrors: OperatorProfileValidationErrors(
            businessName: OperatorProfileMessages.requiredField,
            contactPhone: OperatorProfileMessages.invalidPhone,
            website: OperatorProfileMessages.invalidWebsite,
          ),
        ),
      ],
    );

    blocTest<OperatorProfileCubit, OperatorProfileState>(
      'save() emits savedProfile on success',
      build: () => OperatorProfileCubit(
        getProfile: GetOperatorProfileUseCase(repo),
        updateProfile: UpdateOperatorProfileUseCase(repo),
      ),
      act: (cubit) => cubit.save(
        const UpdateOperatorProfileInput(
          businessName: 'Sun Tours',
          businessDescription: 'Updated',
          businessAddress: '',
          contactPhone: '0901234567',
          contactEmail: 'hello@suntours.vn',
          website: 'https://suntours.vn',
        ),
      ),
      verify: (_) => expect(repo.updateCalls, 1),
      expect: () => [
        const OperatorProfileState(isSubmitting: true),
        const OperatorProfileState(
          status: OperatorProfileLoadStatus.loaded,
          profile: _sampleProfile,
          isSubmitting: false,
          savedProfile: _sampleProfile,
        ),
      ],
    );
  });
}
