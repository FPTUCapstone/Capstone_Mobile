import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';
import 'package:uuid/uuid.dart';

typedef CommercialBookingState = ({
  bool busy,
  CommercialBookingReceipt? receipt,
  String? error,
});

final class CommercialBookingCubit extends Cubit<CommercialBookingState> {
  CommercialBookingCubit(this._repository)
    : super((busy: false, receipt: null, error: null));

  final CommercialBookingRepository _repository;
  CommercialBookingRequest? _previousRequest;
  String? _requestKey;

  Future<List<CommercialOption>> options(int poiId) =>
      _repository.options(poiId);
  Future<List<CommercialSlot>> availability(int serviceId) =>
      _repository.availability(serviceId);

  void clearError() {
    if (state.error != null) {
      emit((busy: state.busy, receipt: state.receipt, error: null));
    }
  }

  Future<void> submit(CommercialBookingRequest request) async {
    if (state.busy || state.receipt != null) return;
    emit((busy: true, receipt: null, error: null));
    try {
      if (_previousRequest != request) {
        _previousRequest = request;
        _requestKey = const Uuid().v4();
      }
      final receipt = await _repository.submit(request, _requestKey!);
      if (!isClosed) emit((busy: false, receipt: receipt, error: null));
    } catch (error) {
      if (!isClosed) {
        emit((
          busy: false,
          receipt: null,
          error: error is Failure ? error.message : 'Không thể gửi yêu cầu.',
        ));
      }
    }
  }
}
