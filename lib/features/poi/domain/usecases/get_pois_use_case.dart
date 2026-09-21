import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';

final class GetPoisUseCase {
  const GetPoisUseCase(this._repository);
  final PoiRepository _repository;

  Future<PagedPoiResult> call(PoiQuery query) => _repository.getPois(query);
}
