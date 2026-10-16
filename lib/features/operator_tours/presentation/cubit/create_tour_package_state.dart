import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';

enum CreateTourPackageStatus { initial, submitting, success, failure }

enum TourPackageOptionsStatus { loading, ready, failure }

final class CreateTourPackageState extends Equatable {
  const CreateTourPackageState({
    this.status = CreateTourPackageStatus.initial,
    this.failure,
    this.tourId,
    this.optionsStatus = TourPackageOptionsStatus.loading,
    this.options,
    this.optionsFailure,
  });
  final CreateTourPackageStatus status;
  final Failure? failure;
  final int? tourId;
  final TourPackageOptionsStatus optionsStatus;
  final TourPackageOptions? options;
  final Failure? optionsFailure;

  CreateTourPackageState copyWith({
    CreateTourPackageStatus? status,
    Failure? failure,
    int? tourId,
    TourPackageOptionsStatus? optionsStatus,
    TourPackageOptions? options,
    Failure? optionsFailure,
    bool clearFailure = false,
    bool clearOptionsFailure = false,
  }) => CreateTourPackageState(
    status: status ?? this.status,
    failure: clearFailure ? null : failure ?? this.failure,
    tourId: tourId ?? this.tourId,
    optionsStatus: optionsStatus ?? this.optionsStatus,
    options: options ?? this.options,
    optionsFailure: clearOptionsFailure
        ? null
        : optionsFailure ?? this.optionsFailure,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    tourId,
    optionsStatus,
    options,
    optionsFailure,
  ];
}
