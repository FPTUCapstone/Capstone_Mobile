import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';

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
    this.pendingStops,
    this.shiftedArrivals = const {},
    this.undoStops,
    this.editRevision = 0,
  });

  const ItineraryDetailState.initial()
    : this(status: ItineraryDetailStatus.initial);

  final ItineraryDetailStatus status;
  final ItineraryDetail? detail;
  final String? message;

  /// Stops of the edit being saved (or that just failed).
  final List<ItineraryStop>? pendingStops;

  /// After an edit: minutes each stop's arrival moved, by POI ID.
  final Map<int, int> shiftedArrivals;

  /// The stops before the last edit; set right after an edit so it can be
  /// undone.
  final List<ItineraryStop>? undoStops;

  /// Increases with every saved edit (lets the page offer undo once).
  final int editRevision;

  /// The same state with another [detail]; everything else is kept (UC-10:
  /// AI sentences arriving must not disturb an edit in progress).
  ItineraryDetailState copyWithDetail(ItineraryDetail detail) =>
      ItineraryDetailState(
        status: status,
        detail: detail,
        message: message,
        pendingStops: pendingStops,
        shiftedArrivals: shiftedArrivals,
        undoStops: undoStops,
        editRevision: editRevision,
      );

  bool get isBusy =>
      status == ItineraryDetailStatus.loading ||
      status == ItineraryDetailStatus.actionInProgress;

  /// The owner may change the plan right now: nobody is navigating it and no
  /// other change is being saved.
  bool get canEditNow => detail?.canEdit == true && !isBusy;

  @override
  List<Object?> get props => [
    status,
    detail,
    message,
    pendingStops,
    shiftedArrivals,
    undoStops,
    editRevision,
  ];
}
