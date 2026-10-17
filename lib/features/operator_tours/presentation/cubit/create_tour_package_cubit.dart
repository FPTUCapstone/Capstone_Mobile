import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/services/tour_image_picker.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:uuid/uuid.dart';

/// Editor state for one tour package: creates a new draft, or loads, updates, photographs and
/// submits an existing one. The server is the source of truth; nothing is reported as saved
/// until the server confirmed it.
final class CreateTourPackageCubit extends Cubit<CreateTourPackageState> {
  CreateTourPackageCubit({
    required CreateTourPackageUseCase createTour,
    required LoadTourPackageOptionsUseCase loadOptions,
    GetTourPackageUseCase? getTour,
    UpdateTourPackageUseCase? updateTour,
    SubmitTourForReviewUseCase? submitForReview,
    ManageTourMediaUseCase? media,
    GetPoiDetailUseCase? getPoiDetail,
    TourImagePicker? imagePicker,
  }) : _createTour = createTour,
       _loadOptions = loadOptions,
       _getTour = getTour,
       _updateTour = updateTour,
       _submitForReview = submitForReview,
       _media = media,
       _getPoiDetail = getPoiDetail,
       _imagePicker = imagePicker,
       super(const CreateTourPackageState());
  final CreateTourPackageUseCase _createTour;
  final LoadTourPackageOptionsUseCase _loadOptions;
  final GetTourPackageUseCase? _getTour;
  final UpdateTourPackageUseCase? _updateTour;
  final SubmitTourForReviewUseCase? _submitForReview;
  final ManageTourMediaUseCase? _media;
  final GetPoiDetailUseCase? _getPoiDetail;
  final TourImagePicker? _imagePicker;
  String? _pendingIdempotencyKey;
  String? _pendingPayload;
  String? _pendingUploadKey;
  String? _pendingUploadFingerprint;

  /// Loads the destination and cancellation-policy catalogues. Safe to retry.
  Future<void> loadOptions() async {
    emit(
      state.copyWith(
        optionsStatus: TourPackageOptionsStatus.loading,
        optionsFailure: null,
      ),
    );
    try {
      final options = await _loadOptions();
      if (!isClosed) {
        emit(
          state.copyWith(
            optionsStatus: TourPackageOptionsStatus.ready,
            options: options,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            optionsStatus: TourPackageOptionsStatus.failure,
            optionsFailure: failure,
          ),
        );
      }
    }
  }

  /// Loads an existing package with its photos and readiness for editing or viewing.
  Future<void> loadDetail(int tourId) async {
    emit(
      state.copyWith(
        detailStatus: TourPackageDetailStatus.loading,
        detailFailure: null,
      ),
    );
    try {
      await _refreshDetail(tourId);
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            detailStatus: TourPackageDetailStatus.failure,
            detailFailure: failure,
          ),
        );
      }
    }
  }

  Future<void> _refreshDetail(int tourId) async {
    final getTour = _getTour;
    final media = _media;
    if (getTour == null || media == null) {
      throw const UnknownFailure();
    }
    final results = await (getTour(tourId), media.list(tourId)).wait;
    final detail = results.$1;
    final names = await _resolvePoiNames({
      for (final item in detail.itineraryItems) item.poiId,
    }, state.poiNames);
    if (isClosed) return;
    emit(
      state.copyWith(
        detailStatus: TourPackageDetailStatus.ready,
        detail: detail,
        media: results.$2,
        poiNames: names,
      ),
    );
  }

  Future<Map<int, String>> _resolvePoiNames(
    Set<int> ids,
    Map<int, String> known,
  ) async {
    final lookup = _getPoiDetail;
    final names = Map<int, String>.of(known);
    if (lookup == null) return names;
    await Future.wait([
      for (final id in ids.where((id) => !names.containsKey(id)))
        () async {
          try {
            names[id] = (await lookup(id)).name;
          } on Object {
            // A name is cosmetic; the editor falls back to "Point of interest #id".
          }
        }(),
    ]);
    return names;
  }

  /// Creates a new draft, or replaces the editable data of the loaded package.
  Future<void> submit(TourPackageDraft draft) async {
    if (state.status == CreateTourPackageStatus.submitting) return;
    emit(
      state.copyWith(status: CreateTourPackageStatus.submitting, failure: null),
    );
    try {
      final existing = state.detail;
      final int id;
      if (existing == null) {
        id = await _createWithStableKey(draft);
      } else {
        await _requireUpdate()(existing.id, draft);
        await _refreshDetail(existing.id);
        id = existing.id;
      }
      if (!isClosed) {
        emit(
          state.copyWith(status: CreateTourPackageStatus.success, tourId: id),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CreateTourPackageStatus.failure,
            failure: failure,
          ),
        );
      }
    }
  }

  Future<int> _createWithStableKey(TourPackageDraft draft) async {
    // The same payload retried after a failed/lost response reuses its key, so the
    // server replays the original draft; any edit starts a new operation.
    final payload = jsonEncode(draft.toJson());
    if (_pendingPayload != payload) {
      _pendingPayload = payload;
      _pendingIdempotencyKey = const Uuid().v4();
    }
    final id = await _createTour(draft, _pendingIdempotencyKey!);
    _pendingIdempotencyKey = null;
    _pendingPayload = null;
    return id;
  }

  UpdateTourPackageUseCase _requireUpdate() =>
      _updateTour ?? (throw const UnknownFailure());

  /// Saves the form, then asks the server to move the package to review. The server decides
  /// whether the prerequisites are met; a refusal leaves the package a Draft.
  Future<void> saveAndSubmitForReview(TourPackageDraft draft) async {
    final existing = state.detail;
    final submit = _submitForReview;
    if (existing == null ||
        submit == null ||
        state.reviewStatus == TourReviewStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        reviewStatus: TourReviewStatus.submitting,
        reviewFailure: null,
      ),
    );
    try {
      await _requireUpdate()(existing.id, draft);
      await submit(existing.id);
      await _refreshDetail(existing.id);
      if (!isClosed) {
        emit(state.copyWith(reviewStatus: TourReviewStatus.submitted));
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            reviewStatus: TourReviewStatus.failure,
            reviewFailure: failure,
          ),
        );
      }
      // The save may have succeeded even though the review request did not.
      try {
        await _refreshDetail(existing.id);
      } on Failure {
        // Keep the earlier detail; the failure above is what the operator needs to see.
      }
    }
  }

  /// Picks one image and uploads it. The first image becomes the cover photo.
  Future<void> addImage() async {
    final detail = state.detail;
    final media = _media;
    final picker = _imagePicker;
    if (detail == null || media == null || picker == null || state.mediaBusy) {
      return;
    }
    emit(state.copyWith(mediaBusy: true, mediaFailure: null));
    try {
      final image = await picker.pickImage();
      if (image == null) {
        emit(state.copyWith(mediaBusy: false));
        return;
      }
      // One key per picked file: retrying the same file after a lost response replays the upload.
      final fingerprint = '${image.fileName}:${image.bytes.length}';
      if (_pendingUploadFingerprint != fingerprint) {
        _pendingUploadFingerprint = fingerprint;
        _pendingUploadKey = const Uuid().v4();
      }
      await media.upload(
        detail.id,
        image,
        altText: '${detail.title} - ${image.fileName}',
        makePrimary: state.media.isEmpty,
        idempotencyKey: _pendingUploadKey!,
      );
      _pendingUploadFingerprint = null;
      _pendingUploadKey = null;
      await _afterMediaChange(detail.id);
    } on TourImageReadFailure {
      emit(
        state.copyWith(
          mediaBusy: false,
          mediaFailure: const ValidationFailure(
            'Choose a JPG or PNG image up to 5 MB.',
          ),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          mediaBusy: false,
          mediaFailure: ErrorMapper.toFailure(error),
        ),
      );
    }
  }

  Future<void> setPrimaryImage(int mediaId) =>
      _mediaAction((media, tourId) => media.setPrimary(tourId, mediaId));

  Future<void> deleteImage(int mediaId) =>
      _mediaAction((media, tourId) => media.delete(tourId, mediaId));

  Future<void> _mediaAction(
    Future<void> Function(ManageTourMediaUseCase media, int tourId) action,
  ) async {
    final detail = state.detail;
    final media = _media;
    if (detail == null || media == null || state.mediaBusy) return;
    emit(state.copyWith(mediaBusy: true, mediaFailure: null));
    try {
      await action(media, detail.id);
      await _afterMediaChange(detail.id);
    } on Object catch (error) {
      emit(
        state.copyWith(
          mediaBusy: false,
          mediaFailure: ErrorMapper.toFailure(error),
        ),
      );
    }
  }

  Future<void> _afterMediaChange(int tourId) async {
    await _refreshDetail(tourId);
    if (!isClosed) emit(state.copyWith(mediaBusy: false));
  }
}
