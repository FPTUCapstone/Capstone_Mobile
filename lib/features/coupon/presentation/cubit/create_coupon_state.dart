import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/eligible_coupon_tour.dart';

enum CreateCouponStatus {
  initial,
  loadingTours,
  tourLoadFailure,
  ready,
  submitting,
  success,
  submissionFailure,
}

final class CreateCouponState extends Equatable {
  const CreateCouponState({
    this.status = CreateCouponStatus.initial,
    this.tours = const [],
    this.failure,
    this.createdCode,
  });
  final CreateCouponStatus status;
  final List<EligibleCouponTour> tours;
  final Failure? failure;
  final String? createdCode;

  CreateCouponState copyWith({
    CreateCouponStatus? status,
    List<EligibleCouponTour>? tours,
    Failure? failure,
    String? createdCode,
    bool clearFailure = false,
    bool clearCreatedCode = false,
  }) => CreateCouponState(
    status: status ?? this.status,
    tours: tours ?? this.tours,
    failure: clearFailure ? null : failure ?? this.failure,
    createdCode: clearCreatedCode ? null : createdCode ?? this.createdCode,
  );

  @override
  List<Object?> get props => [status, tours, failure, createdCode];
}
