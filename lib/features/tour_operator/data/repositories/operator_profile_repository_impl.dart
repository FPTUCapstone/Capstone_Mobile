import 'package:trip_mate_mobile/features/tour_operator/data/datasources/operator_profile_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';

final class OperatorProfileRepositoryImpl implements OperatorProfileRepository {
  const OperatorProfileRepositoryImpl(this._remoteDataSource);

  final OperatorProfileRemoteDataSource _remoteDataSource;

  @override
  Future<OperatorProfile> getProfile() => _remoteDataSource.getProfile();

  @override
  Future<OperatorProfile> updateProfile(UpdateOperatorProfileInput input) =>
      _remoteDataSource.updateProfile(input);
}
