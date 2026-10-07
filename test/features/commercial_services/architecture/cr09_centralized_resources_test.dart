import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';

void main() {
  group('CR-09 Centralized Resources Architecture Test', () {
    test('CommercialServiceEn exposes all required resource namespaces', () {
      expect(CommercialServiceEn.search, isNotNull);
      expect(CommercialServiceEn.detail, isNotNull);
      expect(CommercialServiceEn.booking, isNotNull);
      expect(CommercialServiceEn.messages, isNotNull);
      expect(CommercialServiceEn.demo, isNotNull);
      expect(CommercialServiceEn.accessibility, isNotNull);

      // Verify specific canonical strings
      expect(CommercialServiceEn.search.title, equals('Commercial Services'));
      expect(
        CommercialServiceEn.booking.title,
        equals('Commercial Service Booking'),
      );
      expect(
        CommercialServiceEn.messages.requestCancelled,
        contains('If a payment had been collected'),
      );
    });

    test(
      'Commercial presentation pages contain zero hardcoded user-facing string literals in UI widgets',
      () {
        final presentationDir = Directory(
          'lib/features/commercial_services/presentation/pages',
        );
        expect(
          presentationDir.existsSync(),
          isTrue,
          reason: 'presentation/pages directory must exist',
        );

        final dartFiles = presentationDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        expect(dartFiles, isNotEmpty);

        final violations = <String>[];

        // Regex patterns detecting raw user-visible string literals inside widgets
        // Disallows raw words (2+ letters) directly passed to UI string parameters
        final textPattern = RegExp(
          r'''Text\(\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final labelTextPattern = RegExp(
          r'''labelText:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final hintTextPattern = RegExp(
          r'''hintText:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final tooltipPattern = RegExp(
          r'''tooltip:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final semanticsLabelPattern = RegExp(
          r'''Semantics\([^)]*label:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );

        for (final file in dartFiles) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();

            // Skip comments
            if (trimmed.startsWith('//') ||
                trimmed.startsWith('/*') ||
                trimmed.startsWith('*')) {
              continue;
            }

            // Exclude ValueKey, Key, debugPrint, route paths
            if (line.contains("Key('") ||
                line.contains('Key("') ||
                line.contains('AppRoutes.') ||
                line.contains("path: '")) {
              continue;
            }

            if (textPattern.hasMatch(line)) {
              final match = textPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw Text literal: "$match"',
              );
            }
            if (labelTextPattern.hasMatch(line)) {
              final match = labelTextPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw labelText literal: "$match"',
              );
            }
            if (hintTextPattern.hasMatch(line)) {
              final match = hintTextPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw hintText literal: "$match"',
              );
            }
            if (tooltipPattern.hasMatch(line)) {
              final match = tooltipPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw tooltip literal: "$match"',
              );
            }
            if (semanticsLabelPattern.hasMatch(line)) {
              final match = semanticsLabelPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw Semantics label literal: "$match"',
              );
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'CR-09 VIOLATION: Hardcoded string literals found in commercial presentation pages:\n'
              '${violations.join('\n')}\n'
              'All user-visible UI text MUST be centralized in CommercialServiceEn.',
        );
      },
    );

    test(
      'Commercial entry points in traveler_shell_page.dart use CommercialServiceEn (PR #32 commercial scope)',
      () {
        final shellFile = File(
          'lib/features/traveler/presentation/pages/traveler_shell_page.dart',
        );
        expect(shellFile.existsSync(), isTrue);

        final content = shellFile.readAsStringSync();

        // Check imports
        expect(
          content,
          contains(
            "import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';",
          ),
          reason: 'traveler_shell_page.dart must import CommercialServiceEn',
        );

        // Verify that commercial entry buttons do NOT use raw strings
        expect(
          content,
          contains(
            'key: const Key(\'traveler_home_commercial_services_button\')',
          ),
          reason: 'Home commercial button must exist with expected test key',
        );
        expect(
          content,
          contains(
            'key: const Key(\'traveler_bookings_commercial_services_button\')',
          ),
          reason:
              'Bookings commercial button must exist with expected test key',
        );

        // Verify both button labels use CommercialServiceEn.search.title
        final lines = content.split('\n');
        var verifiedButtons = 0;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('traveler_home_commercial_services_button') ||
              lines[i].contains(
                'traveler_bookings_commercial_services_button',
              )) {
            // Check subsequent lines for CommercialServiceEn.search.title
            final window = lines
                .sublist(i, (i + 7).clamp(0, lines.length))
                .join('\n');
            if (window.contains('CommercialServiceEn.search.title')) {
              verifiedButtons++;
            }
          }
        }

        expect(
          verifiedButtons,
          equals(2),
          reason:
              'Both commercial entry points in traveler_shell_page must use CommercialServiceEn.search.title',
        );
      },
    );

    test(
      'Commercial entry points in poi_detail_page.dart use CommercialServiceEn and do not expose BR-87',
      () {
        final poiDetailFile = File(
          'lib/features/poi/presentation/pages/poi_detail_page.dart',
        );
        expect(poiDetailFile.existsSync(), isTrue);

        final content = poiDetailFile.readAsStringSync();

        // Check import
        expect(
          content,
          contains(
            "import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';",
          ),
          reason: 'poi_detail_page.dart must import CommercialServiceEn',
        );

        // Verify commercial section uses CommercialServiceEn.entryPoints
        expect(
          content,
          matches(
            RegExp(
              r'CommercialServiceEn\s*\.\s*entryPoints\s*\.\s*poiSectionTitle',
            ),
          ),
          reason:
              'poi_detail_page.dart must use CommercialServiceEn.entryPoints.poiSectionTitle',
        );
        expect(
          content,
          matches(
            RegExp(
              r'CommercialServiceEn\s*\.\s*entryPoints\s*\.\s*poiSectionDescription',
            ),
          ),
          reason:
              'poi_detail_page.dart must use CommercialServiceEn.entryPoints.poiSectionDescription',
        );
        expect(
          content,
          matches(
            RegExp(
              r'CommercialServiceEn\s*\.\s*entryPoints\s*\.\s*viewServiceButton',
            ),
          ),
          reason:
              'poi_detail_page.dart must use CommercialServiceEn.entryPoints.viewServiceButton',
        );
        expect(
          content,
          matches(
            RegExp(
              r'CommercialServiceEn\s*\.\s*entryPoints\s*\.\s*demoServiceButton',
            ),
          ),
          reason:
              'poi_detail_page.dart must use CommercialServiceEn.entryPoints.demoServiceButton',
        );

        // Disallowed raw rendered literals
        expect(
          content,
          isNot(contains("'View Commercial Service'")),
          reason:
              'poi_detail_page.dart must not contain raw string literal "View Commercial Service"',
        );
        expect(
          content,
          isNot(contains("'Demo Commercial Service Flow'")),
          reason:
              'poi_detail_page.dart must not contain raw string literal "Demo Commercial Service Flow"',
        );
        expect(
          content,
          isNot(
            contains(
              'This Point of Interest belongs to a commercial service category (BR-87)',
            ),
          ),
          reason:
              'poi_detail_page.dart must not expose BR-87 or raw commercial category description in source',
        );
        expect(
          content,
          isNot(contains('(BR-87)')),
          reason:
              'poi_detail_page.dart must never render "(BR-87)" to end users',
        );
      },
    );

    test(
      'Commercial entry points in itinerary_detail_page.dart use CommercialServiceEn',
      () {
        final itineraryFile = File(
          'lib/features/traveler/presentation/pages/itinerary_detail_page.dart',
        );
        expect(itineraryFile.existsSync(), isTrue);

        final content = itineraryFile.readAsStringSync();

        // Check import
        expect(
          content,
          contains(
            "import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';",
          ),
          reason: 'itinerary_detail_page.dart must import CommercialServiceEn',
        );

        // Verify button uses CommercialServiceEn.entryPoints.viewServiceButton
        expect(
          content,
          matches(
            RegExp(
              r'CommercialServiceEn\s*\.\s*entryPoints\s*\.\s*viewServiceButton',
            ),
          ),
          reason:
              'itinerary_detail_page.dart must use CommercialServiceEn.entryPoints.viewServiceButton',
        );

        // Disallowed raw commercial label
        expect(
          content,
          isNot(contains("'View Commercial Service'")),
          reason:
              'itinerary_detail_page.dart must not contain raw string literal "View Commercial Service"',
        );
      },
    );

    test(
      'Rendered strings in CommercialServiceEn contain zero raw numeric BR / MSG identifiers',
      () {
        // Collect all string instances from CommercialServiceEn namespaces
        final strings = <String>[
          // Search
          CommercialServiceEn.search.title,
          CommercialServiceEn.search.searchHint,
          CommercialServiceEn.search.categoryAll,
          CommercialServiceEn.search.categoryHotel,
          CommercialServiceEn.search.categoryVehicle,
          CommercialServiceEn.search.categoryRestaurant,
          CommercialServiceEn.search.productionNotice,
          CommercialServiceEn.search.catalogPendingTitle,
          CommercialServiceEn.search.catalogPendingNotice,
          CommercialServiceEn.search.catalogPendingExplanation,
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

          // Detail
          CommercialServiceEn.detail.title,
          CommercialServiceEn.detail.poiDetailTitle,
          CommercialServiceEn.detail.poiUnavailableTitle,
          CommercialServiceEn.detail.unableToLoadTitle,
          CommercialServiceEn.detail.serviceInformation,
          CommercialServiceEn.detail.categoryLabel,
          CommercialServiceEn.detail.addressLabel,
          CommercialServiceEn.detail.addressNotProvided,
          CommercialServiceEn.detail.coordinatesLabel,
          CommercialServiceEn.detail.contactInformationLabel,
          CommercialServiceEn.detail.priceRangeLabel,
          CommercialServiceEn.detail.pendingNotReturnedByPoi,
          CommercialServiceEn.detail.openingHoursTitle,
          CommercialServiceEn.detail.viewOnMap,
          CommercialServiceEn.detail.returnToDetail,
          CommercialServiceEn.detail.ordinaryPoiBadge,
          CommercialServiceEn.detail.productionPartialSemantics,
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
          CommercialServiceEn.detail.menuHighlights,
          CommercialServiceEn.detail.closed,
          ...CommercialServiceEn.detail.daysOfWeek,
          CommercialServiceEn.detail.categorySpecificPendingNotice(
            'Rooms',
            'rooms',
          ),
          CommercialServiceEn.detail.tableCapacity(4),
          CommercialServiceEn.detail.availableOnDate('2026-10-15', 5),
          CommercialServiceEn.detail.noAvailabilityOnDate('2026-10-15'),
          CommercialServiceEn.detail.timeSlots('09:00 - 18:00'),
          CommercialServiceEn.detail.coordinatesValue(16.0544, 108.2022),

          // Booking
          CommercialServiceEn.booking.title,
          CommercialServiceEn.booking.submitButton,
          CommercialServiceEn.booking.serviceSummaryTitle,
          CommercialServiceEn.booking.bookingDetails,
          CommercialServiceEn.booking.contactInformation,
          CommercialServiceEn.booking.selectedOptionLabel,
          CommercialServiceEn.booking.requestedDateLabel,
          CommercialServiceEn.booking.requestedTimeLabel,
          CommercialServiceEn.booking.quantityLabel,
          CommercialServiceEn.booking.contactNameLabel,
          CommercialServiceEn.booking.contactPhoneLabel,
          CommercialServiceEn.booking.contactEmailLabel,
          CommercialServiceEn.booking.specialRequestsLabel,
          CommercialServiceEn.booking.specialRequestsHint,
          CommercialServiceEn.booking.productionPendingNotice,
          CommercialServiceEn.booking.estimatedAmountPending,
          CommercialServiceEn.booking.estimatedAmountTitle,
          CommercialServiceEn.booking.demoPreviewAmountTitle,
          CommercialServiceEn.booking.demoPreviewAmountCaption,
          CommercialServiceEn.booking.cancelButton,
          CommercialServiceEn.booking.confirmDialogTitle,
          CommercialServiceEn.booking.confirmDialogBody,
          CommercialServiceEn.booking.cancelDialogTitle,
          CommercialServiceEn.booking.cancelDialogBody,
          CommercialServiceEn.booking.statusPendingConfirmation,
          CommercialServiceEn.booking.statusConfirmed,
          CommercialServiceEn.booking.statusRejected,
          CommercialServiceEn.booking.statusCancelled,

          // Messages
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

          // Demo
          CommercialServiceEn.demo.controlsTitle,
          CommercialServiceEn.demo.simulateConfirmButton,
          CommercialServiceEn.demo.simulateRejectButton,
          CommercialServiceEn.demo.simulateClosedService,
          CommercialServiceEn.demo.simulateSlotUnavailable,
          CommercialServiceEn.demo.simulateSystemFailure,
          CommercialServiceEn.demo.scenarioInactivePoi,
          CommercialServiceEn.demo.scenarioClosedForBooking,
          CommercialServiceEn.demo.scenarioSystemFailure,
          CommercialServiceEn.demo.demoModeHeader,
          CommercialServiceEn.demo.presetDateAvailable,
          CommercialServiceEn.demo.presetDateUnavailable,
          CommercialServiceEn.demo.presetPastDate,
          CommercialServiceEn.demo.presetValidDate,

          // Entry Points
          CommercialServiceEn.entryPoints.poiSectionTitle('Hotel'),
          CommercialServiceEn.entryPoints.poiSectionDescription,
          CommercialServiceEn.entryPoints.viewServiceButton,
          CommercialServiceEn.entryPoints.demoServiceButton,

          // Accessibility
          CommercialServiceEn.a11y.backButtonTooltip,
          CommercialServiceEn.a11y.clearSearchTooltip,
          CommercialServiceEn.a11y.decreaseQuantityTooltip,
          CommercialServiceEn.a11y.increaseQuantityTooltip,
          CommercialServiceEn.a11y.quantitySelectedLabel,
          CommercialServiceEn.a11y.closeMapTooltip,
          CommercialServiceEn.a11y.bookServiceForSemantics('Test POI'),
          CommercialServiceEn.a11y.bookServiceDisabledSemantics('Test POI'),
          CommercialServiceEn.a11y.selectOptionSemantics(
            'Option',
            '100000',
            'night',
            2,
          ),
          CommercialServiceEn.a11y.availableDateSemantics('2026-10-15', 3),
          CommercialServiceEn.a11y.unavailableDateSemantics('2026-10-15'),
          CommercialServiceEn.a11y.mapMarkerFor('Test POI'),
          CommercialServiceEn.a11y.galleryPhotoFor('Test POI'),
        ];

        final forbiddenPatterns = RegExp(
          r'\b(BR-(?:34|55|63|76|87|88|89)|MSG(?:69|70|71|72|73|74|75|76|127|01))\b',
        );

        final violations = <String>[];
        for (final str in strings) {
          if (forbiddenPatterns.hasMatch(str)) {
            violations.add('Rendered string exposes numeric code: "$str"');
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Rendered UI strings must never expose internal numeric BR or MSG codes to end users:\n${violations.join('\n')}',
        );
      },
    );
  });
}
