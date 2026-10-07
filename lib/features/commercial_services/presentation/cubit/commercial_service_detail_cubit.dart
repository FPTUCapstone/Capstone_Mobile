import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';

final class CommercialServiceDetailCubit
    extends Cubit<CommercialServiceDetailState> {
  CommercialServiceDetailCubit({
    GetPoiDetailUseCase? getPoiDetail,
    bool isDemoMode = false,
    DemoCommercialServiceStore? demoStore,
  }) : _getPoiDetail = getPoiDetail,
       _demoStore = demoStore ?? DemoCommercialServiceStore.instance,
       super(CommercialServiceDetailState(isDemoMode: isDemoMode));

  final GetPoiDetailUseCase? _getPoiDetail;
  final DemoCommercialServiceStore _demoStore;

  Future<void> load(String rawPoiId, {String? intendedDateIso}) async {
    final effectiveDateIso =
        (intendedDateIso != null && intendedDateIso.trim().isNotEmpty)
        ? intendedDateIso.trim()
        : state.intendedDateIso;

    if (state.isDemoMode) {
      final parsedId = int.tryParse(rawPoiId) ?? 901;
      final scenario = DemoCommercialServiceScenario.fromPoiId(parsedId);
      _emitDemoScenario(
        scenario: scenario,
        rawPoiId: rawPoiId,
        intendedDateIso: effectiveDateIso,
      );
      return;
    }

    final poiId = int.tryParse(rawPoiId);
    if (poiId == null || poiId <= 0) {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.inactiveOrNotFound,
          rawPoiId: rawPoiId,
          intendedDateIso: effectiveDateIso,
          errorMessage: CommercialServiceMessages.msg34,
          clearComposite: true,
          clearNotice: true,
        ),
      );
      return;
    }

    final getPoiDetail = _getPoiDetail;
    if (getPoiDetail == null) {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.failure,
          rawPoiId: rawPoiId,
          intendedDateIso: effectiveDateIso,
          errorMessage: CommercialServiceMessages.msg127,
          clearComposite: true,
          clearNotice: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CommercialServiceDetailStatus.loading,
        rawPoiId: rawPoiId,
        intendedDateIso: effectiveDateIso,
        clearError: true,
        clearNotice: true,
      ),
    );

    try {
      final detail = await getPoiDetail(poiId);
      if (detail.status.trim().toLowerCase() != 'active') {
        // BR-34: The detailed information of a POI is displayed only while the
        // POI has status Active.
        emit(
          state.copyWith(
            status: CommercialServiceDetailStatus.inactiveOrNotFound,
            rawPoiId: rawPoiId,
            errorMessage: CommercialServiceMessages.msg34,
            clearComposite: true,
            clearNotice: true,
          ),
        );
        return;
      }

      final composite = CommercialServiceDetailComposite.fromProductionPoi(
        detail,
      );
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.loaded,
          rawPoiId: rawPoiId,
          composite: composite,
          clearError: true,
          clearNotice: true,
        ),
      );
    } on NotFoundFailure {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.inactiveOrNotFound,
          rawPoiId: rawPoiId,
          errorMessage: CommercialServiceMessages.msg34,
          clearComposite: true,
          clearNotice: true,
        ),
      );
    } on Failure {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.failure,
          rawPoiId: rawPoiId,
          errorMessage: CommercialServiceMessages.msg127,
          clearComposite: true,
          clearNotice: true,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.failure,
          rawPoiId: rawPoiId,
          errorMessage: CommercialServiceMessages.msg127,
          clearComposite: true,
          clearNotice: true,
        ),
      );
    }
  }

  Future<void> retry() async {
    if (state.isDemoMode) {
      _emitDemoScenario(
        scenario: state.demoScenario,
        rawPoiId: state.rawPoiId,
        intendedDateIso: state.intendedDateIso,
      );
      return;
    }
    await load(state.rawPoiId, intendedDateIso: state.intendedDateIso);
  }

  void selectOption(String optionId) {
    emit(state.copyWith(selectedOptionId: optionId));
  }

  /// Updates the intended service date (`BR-55`: display-time availability is
  /// re-evaluated for the selected date and never treated as a reservation).
  void updateIntendedDate(String dateIso) {
    if (dateIso.trim().isEmpty) return;
    if (state.isDemoMode) {
      _emitDemoScenario(
        scenario: state.demoScenario,
        rawPoiId: state.rawPoiId,
        intendedDateIso: dateIso.trim(),
      );
      return;
    }
    emit(state.copyWith(intendedDateIso: dateIso.trim()));
  }

  /// Switches the active Demo scenario (`kDebugMode && ?demo=true` only).
  void selectDemoScenario(DemoCommercialServiceScenario scenario) {
    if (!state.isDemoMode) return;
    _emitDemoScenario(
      scenario: scenario,
      rawPoiId: '${scenario.poiId}',
      intendedDateIso: state.intendedDateIso,
    );
  }

  void _emitDemoScenario({
    required DemoCommercialServiceScenario scenario,
    required String rawPoiId,
    required String intendedDateIso,
  }) {
    if (scenario == DemoCommercialServiceScenario.systemFailure) {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.failure,
          rawPoiId: rawPoiId,
          intendedDateIso: intendedDateIso,
          demoScenario: scenario,
          errorMessage: CommercialServiceMessages.msg127,
          clearComposite: true,
          clearNotice: true,
        ),
      );
      return;
    }

    final composite = _demoStore.resolveComposite(
      scenario: scenario,
      intendedDateIso: intendedDateIso,
    );

    if (!composite.isActivePoi) {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.inactiveOrNotFound,
          rawPoiId: rawPoiId,
          intendedDateIso: intendedDateIso,
          demoScenario: scenario,
          errorMessage: CommercialServiceMessages.msg34,
          clearComposite: true,
          clearNotice: true,
        ),
      );
      return;
    }

    final notice = composite.isOpenForBooking == false
        ? CommercialServiceMessages.msg75
        : null;
    final defaultOptionId = composite.options.isNotEmpty
        ? composite.options.first.optionId
        : null;

    emit(
      state.copyWith(
        status: CommercialServiceDetailStatus.loaded,
        rawPoiId: rawPoiId,
        intendedDateIso: intendedDateIso,
        demoScenario: scenario,
        composite: composite,
        selectedOptionId: defaultOptionId,
        noticeMessage: notice,
        clearNotice: notice == null,
        clearError: true,
      ),
    );
  }
}
