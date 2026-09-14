import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';

final class GetPoiDetailUseCase {
  const GetPoiDetailUseCase(this._repository);
  final PoiRepository _repository;

  Future<PoiDetail> call(int id) => _repository.getPoiDetail(id);
}
