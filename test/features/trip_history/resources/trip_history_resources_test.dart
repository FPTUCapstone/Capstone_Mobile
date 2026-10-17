import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

void main() {
  group('TripHistoryStringsEn CR-09 & BR/MSG Protection', () {
    test('all static strings are non-empty and well-formed', () {
      expect(TripHistoryStringsEn.tripHistoryTitle, isNotEmpty);
      expect(TripHistoryStringsEn.tripReviewTitle, isNotEmpty);
      expect(TripHistoryStringsEn.tabUpcoming, isNotEmpty);
      expect(TripHistoryStringsEn.tabCompleted, isNotEmpty);
      expect(TripHistoryStringsEn.tabCancelled, isNotEmpty);
      expect(TripHistoryStringsEn.emptyListMessage, isNotEmpty);
      expect(TripHistoryStringsEn.errorMessageGeneric, isNotEmpty);
      expect(TripHistoryStringsEn.validationDateRangeInvalid, isNotEmpty);
      expect(TripHistoryStringsEn.validationRatingRequired, isNotEmpty);
      expect(TripHistoryStringsEn.validationFieldRequired, isNotEmpty);
      expect(TripHistoryStringsEn.validationPhotoExceedsLimit, isNotEmpty);
      expect(TripHistoryStringsEn.validationContentPolicyViolation, isNotEmpty);
      expect(TripHistoryStringsEn.reviewReadOnlyNotice, isNotEmpty);
      expect(TripHistoryStringsEn.reviewSubmitSuccess, isNotEmpty);
      expect(TripHistoryStringsEn.reviewUpdateSuccess, isNotEmpty);
      expect(TripHistoryStringsEn.tripInformationUnavailable, isNotEmpty);
    });

    test('no numeric BR or MSG codes leaked in user-facing string values', () {
      final forbiddenPatterns = [
        RegExp(r'\bBR-\d+\b', caseSensitive: false),
        RegExp(r'\bMSG\d+\b', caseSensitive: false),
        RegExp(r'\bBR\d+\b', caseSensitive: false),
      ];

      final stringValues = [
        TripHistoryStringsEn.tripHistoryTitle,
        TripHistoryStringsEn.tripReviewTitle,
        TripHistoryStringsEn.editReviewTitle,
        TripHistoryStringsEn.viewReviewTitle,
        TripHistoryStringsEn.tabUpcoming,
        TripHistoryStringsEn.tabCompleted,
        TripHistoryStringsEn.tabCancelled,
        TripHistoryStringsEn.filterDateRange,
        TripHistoryStringsEn.filterStartDate,
        TripHistoryStringsEn.filterEndDate,
        TripHistoryStringsEn.filterTripType,
        TripHistoryStringsEn.filterAll,
        TripHistoryStringsEn.filterTour,
        TripHistoryStringsEn.filterCommercialService,
        TripHistoryStringsEn.filterItinerary,
        TripHistoryStringsEn.actionViewEticket,
        TripHistoryStringsEn.actionWriteReview,
        TripHistoryStringsEn.actionEditReview,
        TripHistoryStringsEn.actionViewReview,
        TripHistoryStringsEn.actionViewRefundStatus,
        TripHistoryStringsEn.actionViewDetails,
        TripHistoryStringsEn.actionSubmitReview,
        TripHistoryStringsEn.noticeEticketPending,
        TripHistoryStringsEn.noticeReviewNotCompleted,
        TripHistoryStringsEn.noticeReviewAlreadyExists,
        TripHistoryStringsEn.noticeSelfPlannedNoReview,
        TripHistoryStringsEn.refundDialogTitle,
        TripHistoryStringsEn.emptyListMessage,
        TripHistoryStringsEn.errorMessageGeneric,
        TripHistoryStringsEn.validationDateRangeInvalid,
        TripHistoryStringsEn.permissionDenied,
        TripHistoryStringsEn.validationRatingRequired,
        TripHistoryStringsEn.validationFieldRequired,
        TripHistoryStringsEn.validationPhotoExceedsLimit,
        TripHistoryStringsEn.validationPhotoMaxCount,
        TripHistoryStringsEn.validationContentPolicyViolation,
        TripHistoryStringsEn.reviewReadOnlyNotice,
        TripHistoryStringsEn.reviewSubmitSuccess,
        TripHistoryStringsEn.reviewUpdateSuccess,
        TripHistoryStringsEn.reviewEditWindowActive,
        TripHistoryStringsEn.validationPhotoInvalidType,
        TripHistoryStringsEn.photoUnsupportedSample,
        TripHistoryStringsEn.productionIntegrationPending,
        TripHistoryStringsEn.productionReviewMutationDisabled,
        TripHistoryStringsEn.tripInformationUnavailable,
      ];

      for (final value in stringValues) {
        for (final pattern in forbiddenPatterns) {
          expect(
            pattern.hasMatch(value),
            isFalse,
            reason:
                'String "$value" leaked internal requirement code: $pattern',
          );
        }
      }
    });

    test(
      'UC-32 / UC-33 route integration in app_router.dart uses resource-backed copy without hardcoded literal',
      () {
        final routerFile = File('lib/app/router/app_router.dart');
        expect(routerFile.existsSync(), isTrue);
        final content = routerFile.readAsStringSync();

        // Must not contain the hardcoded literal in ErrorView
        expect(
          content.contains("'Trip information unavailable.'"),
          isFalse,
          reason:
              'app_router.dart must not contain hardcoded "Trip information unavailable."',
        );

        // Must use TripHistoryStringsEn.tripInformationUnavailable
        expect(
          content.contains('TripHistoryStringsEn.tripInformationUnavailable'),
          isTrue,
          reason:
              'app_router.dart must reference TripHistoryStringsEn.tripInformationUnavailable',
        );
      },
    );
  });
}
