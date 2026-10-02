import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';

enum ItineraryDetailStatus {
  initial,
  loading,
  loaded,
  actionInProgress,
  failure,
}

final class ItineraryDetailState extends Equatable {
  const ItineraryDetailState({
    required this.status,
    this.detail,
    this.message,
    this.editingPoiIds,
  });

  const ItineraryDetailState.initial()
    : this(status: ItineraryDetailStatus.initial);

  final ItineraryDetailStatus status;
  final ItineraryDetail? detail;
  final String? message;
  final List<int>? editingPoiIds;

  bool get isBusy =>
      status == ItineraryDetailStatus.loading ||
      status == ItineraryDetailStatus.actionInProgress;

  @override
  List<Object?> get props => [status, detail, message, editingPoiIds];
}
