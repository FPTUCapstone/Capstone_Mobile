/// The signed-in traveler's favorite mark on a place. Every call needs a
/// traveler session; failures are thrown as `Failure` subclasses.
abstract interface class PoiFavoriteRepository {
  Future<bool> isFavorite(int poiId);

  /// Turns the mark on or off and returns the saved state.
  Future<bool> setFavorite(int poiId, {required bool isFavorite});
}
