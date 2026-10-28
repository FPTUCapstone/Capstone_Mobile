import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

/// The lazily loaded detail behind the "View details" / refund sheet.
final class TripRecordDetailCubit extends Cubit<TripRecordDetailState> {
  TripRecordDetailCubit({
    required TripRecordsUseCase useCase,
    required this.reference,
  }) : _useCase = useCase,
       super(const TripRecordDetailState());

  final TripRecordRef reference;
  final TripRecordsUseCase _useCase;
  int _requestId = 0;

  Future<void> load() async {
    final request = ++_requestId;
    emit(const TripRecordDetailState());
    try {
      final detail = await _useCase.detail(reference.kind, reference.id);
      if (isClosed || request != _requestId) return;
      emit(
        TripRecordDetailState(
          status: TripRecordDetailStatus.ready,
          detail: detail,
        ),
      );
    } on Object catch (error) {
      if (isClosed || request != _requestId) return;
      emit(_failure(error));
    }
  }

  Future<void> retry() => load();

  /// Only canonical copy ever reaches the sheet, never a server body or exception text.
  TripRecordDetailState _failure(Object error) {
    final (message, canRetry) = switch (error) {
      NotFoundFailure() => (TripHistoryStringsEn.tripRecordUnavailable, false),
      AuthenticationFailure() ||
      PermissionFailure() => (TripHistoryStringsEn.permissionDenied, false),
      _ => (TripHistoryStringsEn.errorMessageGeneric, true),
    };
    return TripRecordDetailState(
      status: TripRecordDetailStatus.failure,
      message: message,
      canRetry: canRetry,
    );
  }
}
