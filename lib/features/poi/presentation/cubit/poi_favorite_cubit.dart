import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_favorite_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/set_poi_favorite_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_favorite_state.dart';

/// The favorite heart of one place, for a signed-in traveler.
final class PoiFavoriteCubit extends Cubit<PoiFavoriteState> {
  PoiFavoriteCubit({
    required GetPoiFavoriteUseCase getFavorite,
    required SetPoiFavoriteUseCase setFavorite,
  }) : _getFavorite = getFavorite,
       _setFavorite = setFavorite,
       super(const PoiFavoriteState());

  final GetPoiFavoriteUseCase _getFavorite;
  final SetPoiFavoriteUseCase _setFavorite;
  int? _poiId;
  bool _hasToggled = false;

  Future<void> load(int poiId) async {
    _poiId = poiId;
    try {
      final isFavorite = await _getFavorite(poiId);
      // A tap made while loading is newer than this answer.
      if (!isClosed && !_hasToggled) {
        emit(PoiFavoriteState(isFavorite: isFavorite));
      }
    } on Failure {
      // The heart stays off: the place page must work without it.
    }
  }

  /// Flips the heart at once and rolls it back when the save fails.
  Future<void> toggle() async {
    final poiId = _poiId;
    if (poiId == null || state.status == PoiFavoriteStatus.saving) return;
    _hasToggled = true;
    final previous = state.isFavorite;
    emit(
      PoiFavoriteState(isFavorite: !previous, status: PoiFavoriteStatus.saving),
    );
    try {
      final saved = await _setFavorite(poiId, isFavorite: !previous);
      if (!isClosed) emit(PoiFavoriteState(isFavorite: saved));
    } on Failure {
      if (!isClosed) {
        emit(
          PoiFavoriteState(
            isFavorite: previous,
            status: PoiFavoriteStatus.saveFailed,
          ),
        );
      }
    }
  }
}
