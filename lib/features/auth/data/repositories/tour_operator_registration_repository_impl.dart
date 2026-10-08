import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/operator_registration_mapper.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_operator_request.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';

final class TourOperatorRegistrationRepositoryImpl
    implements TourOperatorRegistrationRepository {
  const TourOperatorRegistrationRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<void> confirmVerifiedEmail(String firebaseIdToken) async {
    try {
      await _remoteDataSource.confirmOperatorEmail(firebaseIdToken);
    } on OperatorVerificationRemoteRejection catch (error) {
      throw error.toDomain();
    } on OperatorVerificationRemoteUnknown {
      throw const OperatorVerificationUncertain();
    }
  }

  @override
  Future<TourOperatorRegistrationResult> register(
    TourOperatorRegistration registration,
    String firebaseIdToken,
  ) async {
    try {
      final response = await _remoteDataSource.registerOperator(
        RegisterOperatorRequest(registration, firebaseIdToken).toFormData(),
      );
      return response.toDomain();
    } on OperatorRegistrationRemoteRejection catch (error) {
      throw error.toDomain();
    } on OperatorRegistrationRemoteUnknown {
      throw const OperatorRegistrationUncertain();
    }
  }
}
