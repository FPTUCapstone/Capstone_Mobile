import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

enum CreateTourPackageStatus { initial, submitting, success, failure }

final class CreateTourPackageState extends Equatable {
  const CreateTourPackageState({
    this.status = CreateTourPackageStatus.initial,
    this.failure,
    this.tourId,
  });
  final CreateTourPackageStatus status;
  final Failure? failure;
  final int? tourId;
  @override
  List<Object?> get props => [status, failure, tourId];
}
