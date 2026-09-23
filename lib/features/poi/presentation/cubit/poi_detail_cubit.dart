import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_state.dart';

final class PoiDetailCubit extends Cubit<PoiDetailState> {
  PoiDetailCubit(this._getPoiDetail) : super(const PoiDetailState());

  final GetPoiDetailUseCase _getPoiDetail;

  Future<void> load(String rawId) async {
    final id = int.tryParse(rawId);
    if (id == null || id <= 0) {
      emit(PoiDetailState(status: PoiDetailStatus.invalid, rawId: rawId));
      return;
    }
    emit(PoiDetailState(status: PoiDetailStatus.loading, rawId: rawId));
    try {
      final detail = await _getPoiDetail(id);
      emit(
        PoiDetailState(
          status: PoiDetailStatus.success,
          detail: detail,
          rawId: rawId,
        ),
      );
    } on NotFoundFailure catch (failure) {
      emit(
        PoiDetailState(
          status: PoiDetailStatus.notFound,
          failure: failure,
          rawId: rawId,
        ),
      );
    } on Failure catch (failure) {
      emit(
        PoiDetailState(
          status: PoiDetailStatus.failure,
          failure: failure,
          rawId: rawId,
        ),
      );
    }
  }

  Future<void> retry() async {
    final rawId = state.rawId;
    if (rawId != null) await load(rawId);
  }
}
