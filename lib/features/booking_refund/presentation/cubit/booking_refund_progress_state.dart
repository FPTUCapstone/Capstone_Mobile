import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';

enum BookingRefundProgressStatus { initial, loading, success, failure }

final class BookingRefundProgressState extends Equatable {
  const BookingRefundProgressState({
    this.status = BookingRefundProgressStatus.initial,
    this.progress,
    this.failure,
  });

  final BookingRefundProgressStatus status;
  final BookingRefundProgress? progress;
  final Failure? failure;

  @override
  List<Object?> get props => [status, progress, failure];
}
