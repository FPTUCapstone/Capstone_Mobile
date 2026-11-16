import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';

enum PostTripComplaintPhase {
  loading,
  eligible,
  existing,
  ineligible,
  submitting,
  amending,
  failure,
}

final class PostTripComplaintState extends Equatable {
  const PostTripComplaintState({
    this.phase = PostTripComplaintPhase.loading,
    this.context,
    this.category,
    this.detail = '',
    this.evidence = const [],
    this.message,
  });
  final PostTripComplaintPhase phase;
  final PostTripComplaintContext? context;
  final PostTripComplaintReasonCategory? category;
  final String detail;
  final List<SelectedEvidence> evidence;
  final String? message;
  bool get isBusy =>
      phase == PostTripComplaintPhase.submitting ||
      phase == PostTripComplaintPhase.amending;
  PostTripComplaintState copyWith({
    PostTripComplaintPhase? phase,
    PostTripComplaintContext? context,
    PostTripComplaintReasonCategory? category,
    bool clearCategory = false,
    String? detail,
    List<SelectedEvidence>? evidence,
    String? message,
    bool clearMessage = false,
  }) => PostTripComplaintState(
    phase: phase ?? this.phase,
    context: context ?? this.context,
    category: clearCategory ? null : category ?? this.category,
    detail: detail ?? this.detail,
    evidence: evidence ?? this.evidence,
    message: clearMessage ? null : message ?? this.message,
  );
  @override
  List<Object?> get props => [
    phase,
    context,
    category,
    detail,
    evidence,
    message,
  ];
}
