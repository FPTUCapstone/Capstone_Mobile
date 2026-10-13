import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';

void main() {
  group('CommercialServiceEn Resource Integrity (CR-09 & Truth Remediation)', () {
    final brRegex = RegExp(r'\bBR-\d+\b');
    final msgRegex = RegExp(r'\bMSG\d+\b');
    final screenRegex = RegExp(r'Screen #\d+');
    final vietnameseRegex = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
      caseSensitive: false,
    );

    test(
      'search resource strings are English and contain no numeric rule/message IDs',
      () {
        final strings = [
          CommercialServiceEn.search.title,
          CommercialServiceEn.search.searchHint,
          CommercialServiceEn.search.categoryAll,
          CommercialServiceEn.search.categoryHotel,
          CommercialServiceEn.search.categoryVehicle,
          CommercialServiceEn.search.categoryRestaurant,
          CommercialServiceEn.search.productionNotice,
          CommercialServiceEn.search.demoNotice,
          CommercialServiceEn.search.categoryPendingTooltip,
          CommercialServiceEn.search.emptyMessage,
          CommercialServiceEn.search.resetFilters,
          CommercialServiceEn.search.retry,
          CommercialServiceEn.search.loading,
          CommercialServiceEn.search.pendingServerIntegration,
          CommercialServiceEn.search.fromPrice,
          CommercialServiceEn.search.available,
          CommercialServiceEn.search.fullyBooked,
          CommercialServiceEn.search.availabilityMissing,
          CommercialServiceEn.search.viewDetails,
        ];

        for (final s in strings) {
          expect(s.trim(), isNotEmpty);
          expect(brRegex.hasMatch(s), isFalse, reason: 'Contains BR ID: $s');
          expect(msgRegex.hasMatch(s), isFalse, reason: 'Contains MSG ID: $s');
          expect(
            screenRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Screen #: $s',
          );
          expect(
            vietnameseRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Vietnamese: $s',
          );
        }
      },
    );

    test(
      'detail resource strings are English and contain no numeric rule/message IDs',
      () {
        final strings = [
          CommercialServiceEn.detail.title,
          CommercialServiceEn.detail.overview,
          CommercialServiceEn.detail.options,
          CommercialServiceEn.detail.contact,
          CommercialServiceEn.detail.availabilityTitle,
          CommercialServiceEn.detail.intendedDatePrefix,
          CommercialServiceEn.detail.bookService,
          CommercialServiceEn.detail.closedForBooking,
          CommercialServiceEn.detail.availabilityUnavailableNotice,
          CommercialServiceEn.detail.nonCommercialNotice,
          CommercialServiceEn.detail.inactivePoiNotice,
          CommercialServiceEn.detail.productionPendingNotice,
          CommercialServiceEn.detail.availabilityNotice,
          CommercialServiceEn.detail.bookServiceRequiresAvailability,
          CommercialServiceEn.detail.commercialServiceBadge,
          CommercialServiceEn.detail.availableUnitsSuffix,
          CommercialServiceEn.detail.locationMapProjection,
        ];

        for (final s in strings) {
          expect(s.trim(), isNotEmpty);
          expect(brRegex.hasMatch(s), isFalse, reason: 'Contains BR ID: $s');
          expect(msgRegex.hasMatch(s), isFalse, reason: 'Contains MSG ID: $s');
          expect(
            screenRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Screen #: $s',
          );
          expect(
            vietnameseRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Vietnamese: $s',
          );
        }
      },
    );

    test(
      'booking resource strings are English and contain no numeric rule/message IDs',
      () {
        final strings = [
          CommercialServiceEn.booking.title,
          CommercialServiceEn.booking.bookingDetails,
          CommercialServiceEn.booking.selectedOptionLabel,
          CommercialServiceEn.booking.requestedDateLabel,
          CommercialServiceEn.booking.requestedTimeLabel,
          CommercialServiceEn.booking.availableUnitsPrefix,
          CommercialServiceEn.booking.quantityLabel,
          CommercialServiceEn.booking.specialRequestsLabel,
          CommercialServiceEn.booking.specialRequestsHint,
          CommercialServiceEn.booking.contactInformation,
          CommercialServiceEn.booking.contactNameLabel,
          CommercialServiceEn.booking.contactPhoneLabel,
          CommercialServiceEn.booking.contactEmailLabel,
          CommercialServiceEn.booking.estimatedAmountTitle,
          CommercialServiceEn.booking.estimatedAmountPending,
          CommercialServiceEn.booking.demoPreviewAmountTitle,
          CommercialServiceEn.booking.demoPreviewAmountCaption,
          CommercialServiceEn.booking.submitButton,
          CommercialServiceEn.booking.confirmDialogTitle,
          CommercialServiceEn.booking.confirmDialogBody,
          CommercialServiceEn.booking.confirmDialogCancel,
          CommercialServiceEn.booking.confirmDialogAccept,
          CommercialServiceEn.booking.cancelButton,
          CommercialServiceEn.booking.cancelDialogTitle,
          CommercialServiceEn.booking.cancelDialogBody,
          CommercialServiceEn.booking.cancelDialogKeep,
          CommercialServiceEn.booking.cancelDialogConfirm,
          CommercialServiceEn.booking.cancelSuccessNotice,
          CommercialServiceEn.booking.productionPendingNotice,
          CommercialServiceEn.booking.statusPendingConfirmation,
          CommercialServiceEn.booking.statusConfirmed,
          CommercialServiceEn.booking.statusRejected,
          CommercialServiceEn.booking.statusCancelled,
          CommercialServiceEn.booking.newRequestButton,
          CommercialServiceEn.booking.optionPrefix,
          CommercialServiceEn.booking.dateTimePrefix,
          CommercialServiceEn.booking.quantityPrefix,
          CommercialServiceEn.booking.itineraryReflectionNotice,
        ];

        for (final s in strings) {
          expect(s.trim(), isNotEmpty);
          expect(brRegex.hasMatch(s), isFalse, reason: 'Contains BR ID: $s');
          expect(msgRegex.hasMatch(s), isFalse, reason: 'Contains MSG ID: $s');
          expect(
            screenRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Screen #: $s',
          );
          expect(
            vietnameseRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Vietnamese: $s',
          );
        }
      },
    );

    test(
      'message resource strings are English and contain no numeric rule/message IDs',
      () {
        final strings = [
          CommercialServiceEn.messages.requiredField,
          CommercialServiceEn.messages.poiInactive,
          CommercialServiceEn.messages.requestCreated,
          CommercialServiceEn.messages.availabilityUnavailable,
          CommercialServiceEn.messages.quantityExceeded,
          CommercialServiceEn.messages.providerConfirmed,
          CommercialServiceEn.messages.providerRejected,
          CommercialServiceEn.messages.requestCancelled,
          CommercialServiceEn.messages.serviceClosed,
          CommercialServiceEn.messages.requestedDatePast,
          CommercialServiceEn.messages.permissionDenied,
          CommercialServiceEn.messages.systemError,
          CommercialServiceEn.messages.ordinaryPoiNoBooking,
        ];

        for (final s in strings) {
          expect(s.trim(), isNotEmpty);
          expect(brRegex.hasMatch(s), isFalse, reason: 'Contains BR ID: $s');
          expect(msgRegex.hasMatch(s), isFalse, reason: 'Contains MSG ID: $s');
          expect(
            screenRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Screen #: $s',
          );
          expect(
            vietnameseRegex.hasMatch(s),
            isFalse,
            reason: 'Contains Vietnamese: $s',
          );
        }
      },
    );

    test(
      'CommercialServiceMessages delegates correctly to CommercialServiceEn without codes',
      () {
        expect(
          CommercialServiceMessages.msg01,
          CommercialServiceEn.messages.requiredField,
        );
        expect(
          CommercialServiceMessages.msg34,
          CommercialServiceEn.messages.poiInactive,
        );
        expect(
          CommercialServiceMessages.msg69,
          CommercialServiceEn.messages.requestCreated,
        );
        expect(
          CommercialServiceMessages.msg70,
          CommercialServiceEn.messages.availabilityUnavailable,
        );
        expect(
          CommercialServiceMessages.msg71,
          CommercialServiceEn.messages.quantityExceeded,
        );
        expect(
          CommercialServiceMessages.msg72,
          CommercialServiceEn.messages.providerConfirmed,
        );
        expect(
          CommercialServiceMessages.msg73,
          CommercialServiceEn.messages.providerRejected,
        );
        expect(
          CommercialServiceMessages.msg74,
          CommercialServiceEn.messages.requestCancelled,
        );
        expect(
          CommercialServiceMessages.msg75,
          CommercialServiceEn.messages.serviceClosed,
        );
        expect(
          CommercialServiceMessages.msg76,
          CommercialServiceEn.messages.requestedDatePast,
        );
        expect(
          CommercialServiceMessages.msg126,
          CommercialServiceEn.messages.permissionDenied,
        );
        expect(
          CommercialServiceMessages.msg127,
          CommercialServiceEn.messages.systemError,
        );
      },
    );

    test(
      'Part F refund copy uses conditional phrasing without claiming financial transaction occurred',
      () {
        final notice = CommercialServiceEn.booking.cancelSuccessNotice;
        expect(
          notice,
          contains(
            'If a payment had been collected, any refund would be returned through the original payment channel',
          ),
        );
        expect(brRegex.hasMatch(notice), isFalse);
      },
    );
  });
}
