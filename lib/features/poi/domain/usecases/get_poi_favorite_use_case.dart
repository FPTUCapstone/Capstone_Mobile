import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_favorite_repository.dart';

final class GetPoiFavoriteUseCase {
  const GetPoiFavoriteUseCase(this._repository);
  final PoiFavoriteRepository _repository;

  Future<bool> call(int poiId) => _repository.isFavorite(poiId);
}
