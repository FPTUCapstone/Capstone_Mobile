import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/usecases/get_commercial_service_detail.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_state.dart';

final class CommercialServiceDetailCubit
    extends Cubit<CommercialServiceDetailState> {
  CommercialServiceDetailCubit({
    GetCommercialServiceDetail? getCommercialServiceDetail,
    bool isDemoMode = false,
  }) : _getCommercialServiceDetail = getCommercialServiceDetail,
       super(CommercialServiceDetailState(isDemoMode: isDemoMode));

  final GetCommercialServiceDetail? _getCommercialServiceDetail;

  Future<void> load(
    String rawPoiId, {
    String? intendedDateIso,
    DemoCommercialServiceScenario? demoScenario,
  }) async {
    final effectiveDateIso =
        (intendedDateIso != null && intendedDateIso.trim().isNotEmpty)
        ? intendedDateIso.trim()
        : state.intendedDateIso;

    final effectiveScenario =
        demoScenario ??
        (state.isDemoMode
            ? DemoCommercialServiceScenario.fromPoiId(
                int.tryParse(rawPoiId) ?? 901,
              )
            : null);

    emit(
      state.copyWith(
        status: CommercialServiceDetailStatus.loading,
        rawPoiId: rawPoiId,
        intendedDateIso: effectiveDateIso,
        demoScenario: effectiveScenario,
        clearError: true,
        clearNotice: true,
      ),
    );

    final useCase = _getCommercialServiceDetail;
    if (useCase == null) {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.failure,
          rawPoiId: rawPoiId,
          intendedDateIso: effectiveDateIso,
          demoScenario: effectiveScenario,
          errorMessage: CommercialServiceMessages.msg127,
          clearComposite: true,
          clearNotice: true,
        ),
      );
      return;
    }

    try {
      final result = await useCase(
        rawPoiId: rawPoiId,
        intendedDateIso: effectiveDateIso,
        isDemoMode: state.isDemoMode,
        demoScenario: effectiveScenario,
      );

      _handleDetailResult(
        result,
        rawPoiId,
        effectiveDateIso,
        demoScenario: effectiveScenario,
      );
    } on Failure {
      emit(
        state.copyWith(
          status: CommercialServiceDetailStatus.failure,
          rawPoiId: rawPoiId,
          intendedDateIso: effectiveDateIso,
          demoScenario: effectiveScenario,
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
          intendedDateIso: effectiveDateIso,
          demoScenario: effectiveScenario,
          errorMessage: CommercialServiceMessages.msg127,
          clearComposite: true,
          clearNotice: true,
        ),
      );
    }
  }

  Future<void> retry() => load(
    state.rawPoiId,
    intendedDateIso: state.intendedDateIso,
    demoScenario: state.demoScenario,
  );

  void selectOption(String optionId) {
    emit(state.copyWith(selectedOptionId: optionId));
  }

  /// Updates the intended service date (`BR-55`: display-time availability is
  /// re-evaluated for the selected date and never treated as a reservation).
  void updateIntendedDate(String dateIso) {
    if (dateIso.trim().isEmpty) return;
    load(
      state.rawPoiId,
      intendedDateIso: dateIso.trim(),
      demoScenario: state.demoScenario,
    );
  }

  /// Switches the active Demo scenario (`kDebugMode && ?demo=true` only).
  void selectDemoScenario(DemoCommercialServiceScenario scenario) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(demoScenario: scenario));
    load(
      '${scenario.poiId}',
      intendedDateIso: state.intendedDateIso,
      demoScenario: scenario,
    );
  }

  void _handleDetailResult(
    CommercialServiceDetailResult result,
    String rawPoiId,
    String effectiveDateIso, {
    DemoCommercialServiceScenario? demoScenario,
  }) {
    switch (result) {
      case CommercialServiceDetailLoaded(
        :final composite,
        :final noticeMessage,
      ):
        final defaultOptionId = composite.options.isNotEmpty
            ? composite.options.first.optionId
            : null;
        emit(
          state.copyWith(
            status: CommercialServiceDetailStatus.loaded,
            rawPoiId: rawPoiId,
            intendedDateIso: effectiveDateIso,
            demoScenario: demoScenario,
            composite: composite,
            selectedOptionId: defaultOptionId,
            noticeMessage: noticeMessage,
            clearNotice: noticeMessage == null,
            clearError: true,
          ),
        );
      case CommercialServiceDetailInactiveOrNotFound(:final message):
        emit(
          state.copyWith(
            status: CommercialServiceDetailStatus.inactiveOrNotFound,
            rawPoiId: rawPoiId,
            intendedDateIso: effectiveDateIso,
            demoScenario: demoScenario,
            errorMessage: message ?? CommercialServiceMessages.msg34,
            clearComposite: true,
            clearNotice: true,
          ),
        );
      case CommercialServiceDetailFailure(:final message):
        emit(
          state.copyWith(
            status: CommercialServiceDetailStatus.failure,
            rawPoiId: rawPoiId,
            intendedDateIso: effectiveDateIso,
            demoScenario: demoScenario,
            errorMessage: message ?? CommercialServiceMessages.msg127,
            clearComposite: true,
            clearNotice: true,
          ),
        );
    }
  }
}
