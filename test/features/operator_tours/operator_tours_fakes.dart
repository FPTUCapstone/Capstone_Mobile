import 'dart:async';

import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/services/tour_image_picker.dart';

TourPackageDraft sampleDraft({String title = 'Da Nang day tour'}) =>
    TourPackageDraft(
      title: title,
      description: 'Description',
      basePrice: 1000000,
      durationDays: 1,
      destinationIds: const [1, 2],
      cancellationPolicyTemplateId: 7,
      itineraryItems: const [
        TourItineraryStopDraft(
          poiId: 1,
          dayNo: 1,
          sequenceNo: 1,
          stayDurationMinutes: 60,
        ),
      ],
      schedules: [
        TourScheduleDraft(
          startAtUtc: DateTime.utc(2026, 11, 1, 8),
          endAtUtc: DateTime.utc(2026, 11, 1, 16),
          totalCapacity: 20,
        ),
      ],
    );

TourPackageDetail sampleDetail({
  int id = 42,
  TourPackageStatus status = TourPackageStatus.draft,
  List<String> blockers = const ['primary_image_missing'],
  String? rejectionReason,
}) => TourPackageDetail(
  id: id,
  title: 'Da Nang day tour',
  description: 'Description',
  status: status,
  basePrice: 1000000,
  durationDays: 1,
  destinationIds: const [1, 2],
  destinationNames: const ['Da Nang', 'Hoi An'],
  cancellationPolicyTemplateId: 7,
  timeZoneId: 'Asia/Bangkok',
  categoryId: 3,
  rejectionReason: rejectionReason,
  highlights: 'Cable car',
  itineraryItems: const [
    TourItineraryItemDetail(
      dayNo: 1,
      sequenceNo: 1,
      poiId: 11,
      stayDurationMinutes: 90,
      plannedTime: '08:00:00',
    ),
  ],
  departures: [
    TourDepartureDetail(
      startAtUtc: DateTime.utc(2027, 3, 1, 1),
      endAtUtc: DateTime.utc(2027, 3, 1, 9),
      minimumCapacity: 4,
      totalCapacity: 20,
      reservedCapacity: 0,
      adultPrice: 1200000,
    ),
  ],
  reviewBlockers: blockers,
  warnings: const [
    TourWarning(code: 'duplicate_poi', dayNo: 1, sequenceNo: 2, poiId: 11),
  ],
  canSubmitForReview: blockers.isEmpty && status.isEditable,
  hasPrimaryImage: blockers.isEmpty,
  mediaCount: blockers.isEmpty ? 1 : 0,
);

/// Records every call so tests can assert exactly what reached the server.
final class FakeOperatorTourRepository implements OperatorTourRepository {
  FakeOperatorTourRepository({
    this.failCreates = 0,
    this.failOptionLoads = 0,
    this.failSubmitWith,
    this.failUploads = 0,
    TourPackageDetail? detail,
  }) : detail = detail ?? sampleDetail();
  bool failReadsAfterSubmit = false;
  bool lostSubmitResponse = false;
  final submissionNotes = <String?>[];
  Completer<void>? updateGate;
  int failCreates;
  int failOptionLoads;
  int failUploads;
  Failure? failSubmitWith;
  TourPackageDetail detail;
  final createKeys = <String>[];
  final updates = <(int, TourPackageDraft)>[];
  final addedDepartures = <(int, TourScheduleDraft, String)>[];
  final deletedTourIds = <int>[];
  final submitted = <int>[];
  final uploads = <({String altText, bool makePrimary, String key})>[];
  final primaryCalls = <int>[];
  final deleteCalls = <int>[];
  final listCalls = <({String? status, int page})>[];
  List<TourMediaItem> media = [];
  List<TourPackageSummary> allTours = [];

  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) async {
    createKeys.add(idempotencyKey);
    if (failCreates > 0) {
      failCreates -= 1;
      throw const NetworkFailure();
    }
    return 42;
  }

  @override
  Future<TourPackageOptions> loadOptions() async {
    if (failOptionLoads > 0) {
      failOptionLoads -= 1;
      throw const NetworkFailure();
    }
    return const TourPackageOptions(
      destinations: [
        TourDestinationOption(id: 1, name: 'Da Nang'),
        TourDestinationOption(id: 2, name: 'Hoi An'),
      ],
      policies: [CancellationPolicyOption(id: 7, name: 'Standard')],
    );
  }

  @override
  Future<TourPackagePage> listTours({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls.add((status: status, page: page));
    if (allTours.any((tour) => tour.title == 'FAIL')) {
      throw const NetworkFailure();
    }
    final matching = allTours
        .where((tour) => status == null || tour.status.apiName == status)
        .toList();
    final start = (page - 1) * pageSize;
    return TourPackagePage(
      items: matching.skip(start).take(pageSize).toList(),
      page: page,
      totalCount: matching.length,
    );
  }

  @override
  Future<TourPackageDetail> getTour(int tourId) async {
    if (failReadsAfterSubmit && submitted.isNotEmpty) {
      throw const NetworkFailure();
    }
    return detail;
  }

  @override
  Future<void> updateDraft(int tourId, TourPackageDraft draft) async {
    updates.add((tourId, draft));
    await updateGate?.future;
  }

  @override
  Future<void> deleteTour(int tourId) async {
    deletedTourIds.add(tourId);
  }

  @override
  Future<TourDepartureDetail> addDeparture(
    int tourId,
    TourScheduleDraft departure,
    String idempotencyKey,
  ) async {
    addedDepartures.add((tourId, departure, idempotencyKey));
    final created = TourDepartureDetail(
      id: 900 + addedDepartures.length,
      status: 'Scheduled',
      startAtUtc: departure.startAtUtc,
      endAtUtc: departure.endAtUtc,
      minimumCapacity: departure.minimumCapacity,
      totalCapacity: departure.totalCapacity,
      reservedCapacity: 0,
      meetingPoint: departure.meetingPoint,
      registrationDeadlineAtUtc: departure.registrationDeadlineAtUtc,
      adultPrice: departure.adultPrice,
      childPrice: departure.childPrice,
      infantPrice: departure.infantPrice,
      meetingLatitude: departure.meetingLatitude,
      meetingLongitude: departure.meetingLongitude,
    );
    detail = TourPackageDetail(
      id: detail.id,
      title: detail.title,
      description: detail.description,
      status: detail.status,
      basePrice: detail.basePrice,
      durationDays: detail.durationDays,
      destinationIds: detail.destinationIds,
      destinationNames: detail.destinationNames,
      cancellationPolicyTemplateId: detail.cancellationPolicyTemplateId,
      cancellationFeeRules: detail.cancellationFeeRules,
      itineraryItems: detail.itineraryItems,
      departures: [...detail.departures, created],
      reviewBlockers: detail.reviewBlockers,
      warnings: detail.warnings,
      canSubmitForReview: detail.canSubmitForReview,
      hasPrimaryImage: detail.hasPrimaryImage,
      mediaCount: detail.mediaCount,
      versionNo: detail.versionNo,
      publishedAtUtc: detail.publishedAtUtc,
      allowDeposit: detail.allowDeposit,
      depositPercent: detail.depositPercent,
      balanceDueDaysBeforeDeparture: detail.balanceDueDaysBeforeDeparture,
      versions: detail.versions,
      categoryId: detail.categoryId,
      timeZoneId: detail.timeZoneId,
      highlights: detail.highlights,
      inclusions: detail.inclusions,
      exclusions: detail.exclusions,
      travellerRequirements: detail.travellerRequirements,
      rejectionReason: detail.rejectionReason,
      submissionNote: detail.submissionNote,
      submittedAtUtc: detail.submittedAtUtc,
    );
    return created;
  }

  @override
  Future<TourReviewSubmission> submitForReview(
    int tourId, {
    String? submissionNote,
  }) async {
    submitted.add(tourId);
    submissionNotes.add(submissionNote);
    final failure = failSubmitWith;
    if (failure != null) throw failure;
    detail = sampleDetail(
      status: TourPackageStatus.pending,
      blockers: const [],
    );
    if (lostSubmitResponse) throw const NetworkFailure();
    return TourReviewSubmission(tourId: tourId);
  }

  @override
  Future<List<TourMediaItem>> listMedia(int tourId) async => media;

  @override
  Future<void> uploadMedia(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  }) async {
    uploads.add((
      altText: altText,
      makePrimary: makePrimary,
      key: idempotencyKey,
    ));
    if (failUploads > 0) {
      failUploads -= 1;
      throw const NetworkFailure();
    }
    media = [
      ...media,
      TourMediaItem(
        id: media.length + 1,
        url: 'https://cdn.test/${media.length + 1}.jpg',
        isPrimary: makePrimary,
      ),
    ];
    detail = sampleDetail(blockers: const []);
  }

  @override
  Future<void> setPrimaryMedia(int tourId, int mediaId) async {
    primaryCalls.add(mediaId);
    media = [
      for (final item in media)
        TourMediaItem(
          id: item.id,
          url: item.url,
          isPrimary: item.id == mediaId,
        ),
    ];
  }

  @override
  Future<void> deleteMedia(int tourId, int mediaId) async {
    deleteCalls.add(mediaId);
    media = media.where((item) => item.id != mediaId).toList();
  }
}

final class FakeTourImagePicker implements TourImagePicker {
  FakeTourImagePicker({this.image, this.failure});
  TourImageUpload? image;
  Object? failure;
  int picks = 0;
  Completer<TourImageUpload?>? pickGate;

  @override
  Future<TourImageUpload?> pickImage() async {
    picks += 1;
    if (pickGate != null) return pickGate!.future;
    if (failure != null) throw failure!;
    return image;
  }
}
