import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';

/// UC-32: the Traveler's trips for one tab, and one trip's detail.
final class TripRecordsUseCase {
  const TripRecordsUseCase(this._repository);

  final TripRecordsRepository _repository;

  Future<TripRecordPage> page(TripRecordsQuery query) =>
      _repository.getPage(query);

  Future<TripRecordDetail> detail(TripRecordKind kind, int id) =>
      _repository.getDetail(kind, id);
}
