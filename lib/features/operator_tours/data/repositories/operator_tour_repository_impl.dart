import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/datasources/operator_tour_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';

final class OperatorTourRepositoryImpl implements OperatorTourRepository {
  const OperatorTourRepositoryImpl(this._remote);
  final OperatorTourRemoteDataSource _remote;
  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) async {
    try {
      return await _remote.createDraft(draft, idempotencyKey);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
