import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_favorite_repository.dart';

final class SetPoiFavoriteUseCase {
  const SetPoiFavoriteUseCase(this._repository);
  final PoiFavoriteRepository _repository;

  /// Returns the saved state.
  Future<bool> call(int poiId, {required bool isFavorite}) =>
      _repository.setFavorite(poiId, isFavorite: isFavorite);
}
