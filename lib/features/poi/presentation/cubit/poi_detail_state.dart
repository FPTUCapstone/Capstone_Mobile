import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';

enum PoiDetailStatus { initial, loading, success, invalid, notFound, failure }

final class PoiDetailState extends Equatable {
  const PoiDetailState({
    this.status = PoiDetailStatus.initial,
    this.detail,
    this.failure,
    this.rawId,
  });

  final PoiDetailStatus status;
  final PoiDetail? detail;
  final Failure? failure;
  final String? rawId;

  @override
  List<Object?> get props => [status, detail, failure, rawId];
}
