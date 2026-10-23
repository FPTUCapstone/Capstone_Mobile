import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';

enum TripRecordDetailStatus { loading, ready, failure }

final class TripRecordDetailState extends Equatable {
  const TripRecordDetailState({
    this.status = TripRecordDetailStatus.loading,
    this.detail,
    this.message,
    this.canRetry = false,
  });

  final TripRecordDetailStatus status;
  final TripRecordDetail? detail;

  /// Canonical copy only; never a server body or exception text.
  final String? message;

  /// False for "no longer available" and for access failures: asking again cannot help.
  final bool canRetry;

  @override
  List<Object?> get props => [status, detail, message, canRetry];
}
