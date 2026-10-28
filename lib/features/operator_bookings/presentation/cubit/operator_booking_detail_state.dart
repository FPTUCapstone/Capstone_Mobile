import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

enum OperatorBookingDetailStatus { loading, success, failure }

final class OperatorBookingDetailState extends Equatable {
  const OperatorBookingDetailState({
    this.status = OperatorBookingDetailStatus.loading,
    this.detail,
    this.errorMessage,
    this.canRetry = true,
  });

  final OperatorBookingDetailStatus status;
  final OperatorBookingDetail? detail;
  final String? errorMessage;

  /// False for an access failure: asking again cannot change the answer.
  final bool canRetry;

  @override
  List<Object?> get props => [status, detail, errorMessage, canRetry];
}
