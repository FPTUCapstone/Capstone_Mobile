import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';

enum CreateTourPackageStatus { initial, submitting, success, failure }

enum TourPackageOptionsStatus { loading, ready, failure }

enum TourPackageDetailStatus { idle, loading, ready, failure }

enum TourReviewStatus { idle, submitting, submitted, failure }

const _keep = Object();

final class CreateTourPackageState extends Equatable {
  const CreateTourPackageState({
    this.status = CreateTourPackageStatus.initial,
    this.failure,
    this.tourId,
    this.optionsStatus = TourPackageOptionsStatus.loading,
    this.options,
    this.optionsFailure,
    this.detailStatus = TourPackageDetailStatus.idle,
    this.detail,
    this.detailFailure,
    this.media = const [],
    this.mediaBusy = false,
    this.mediaFailure,
    this.reviewStatus = TourReviewStatus.idle,
    this.reviewFailure,
    this.poiNames = const {},
  });
  final CreateTourPackageStatus status;
  final Failure? failure;
  final int? tourId;
  final TourPackageOptionsStatus optionsStatus;
  final TourPackageOptions? options;
  final Failure? optionsFailure;

  /// Set when an existing package is being edited or viewed.
  final TourPackageDetailStatus detailStatus;
  final TourPackageDetail? detail;
  final Failure? detailFailure;
  final List<TourMediaItem> media;
  final bool mediaBusy;
  final Failure? mediaFailure;
  final TourReviewStatus reviewStatus;
  final Failure? reviewFailure;

  /// Display names for the POIs already in the loaded itinerary (best effort).
  final Map<int, String> poiNames;

  /// Nullable fields use a sentinel so `null` can mean "clear" while omission means "keep".
  CreateTourPackageState copyWith({
    CreateTourPackageStatus? status,
    Object? failure = _keep,
    int? tourId,
    TourPackageOptionsStatus? optionsStatus,
    TourPackageOptions? options,
    Object? optionsFailure = _keep,
    TourPackageDetailStatus? detailStatus,
    TourPackageDetail? detail,
    Object? detailFailure = _keep,
    List<TourMediaItem>? media,
    bool? mediaBusy,
    Object? mediaFailure = _keep,
    TourReviewStatus? reviewStatus,
    Object? reviewFailure = _keep,
    Map<int, String>? poiNames,
  }) => CreateTourPackageState(
    status: status ?? this.status,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    tourId: tourId ?? this.tourId,
    optionsStatus: optionsStatus ?? this.optionsStatus,
    options: options ?? this.options,
    optionsFailure: identical(optionsFailure, _keep)
        ? this.optionsFailure
        : optionsFailure as Failure?,
    detailStatus: detailStatus ?? this.detailStatus,
    detail: detail ?? this.detail,
    detailFailure: identical(detailFailure, _keep)
        ? this.detailFailure
        : detailFailure as Failure?,
    media: media ?? this.media,
    mediaBusy: mediaBusy ?? this.mediaBusy,
    mediaFailure: identical(mediaFailure, _keep)
        ? this.mediaFailure
        : mediaFailure as Failure?,
    reviewStatus: reviewStatus ?? this.reviewStatus,
    reviewFailure: identical(reviewFailure, _keep)
        ? this.reviewFailure
        : reviewFailure as Failure?,
    poiNames: poiNames ?? this.poiNames,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    tourId,
    optionsStatus,
    options,
    optionsFailure,
    detailStatus,
    detail,
    detailFailure,
    media,
    mediaBusy,
    mediaFailure,
    reviewStatus,
    reviewFailure,
    poiNames,
  ];
}
