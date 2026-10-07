import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';

/// Semantic application messages for UC-30 (View Commercial Service) and
/// UC-31 (Book Commercial Service) aligned with Report 3 SRS V2 Sections 3.6.1
/// and 3.6.2.
///
/// Note on internal SRS conflicts:
/// - SRS_INTERNAL_CONFLICT_COMMERCIAL_MESSAGE_IDS: Detailed UC-31 assigns
///   MSG69–MSG76 to commercial booking operations, whereas Appendix 5.3 reuses
///   the same numeric IDs for Tour Package management.
/// - Numeric message IDs are strictly omitted from rendered user-facing copy
///   to avoid surfacing internal SRS contradictions to users.
abstract final class CommercialServiceMessages {
  /// Required booking field left empty (detailed UC-31 Abnormal Case 3.a1).
  static String get msg01 => CommercialServiceEn.messages.requiredField;
  static String get requiredField => msg01;

  /// POI is not Active or no longer exists (detailed UC-30 BR-34).
  static String get msg34 => CommercialServiceEn.messages.poiInactive;
  static String get poiInactive => msg34;

  /// Commercial service booking request created in `Pending Confirmation` status
  /// (detailed UC-31 Normal Flow step 7).
  static String get msg69 => CommercialServiceEn.messages.requestCreated;
  static String get requestCreated => msg69;

  /// Requested date or requested time is unavailable (detailed UC-31 Abnormal Case 7.a1).
  static String get msg70 =>
      CommercialServiceEn.messages.availabilityUnavailable;
  static String get availabilityUnavailable => msg70;

  /// Requested quantity exceeds available units (detailed UC-31 Abnormal Case 7.a2).
  static String get msg71 => CommercialServiceEn.messages.quantityExceeded;
  static String get quantityExceeded => msg71;

  /// Commercial service provider confirms the request (detailed UC-31 Alternative Flow).
  static String get msg72 => CommercialServiceEn.messages.providerConfirmed;
  static String get providerConfirmed => msg72;

  /// Commercial service provider rejects the request (detailed UC-31 Alternative Flow).
  static String get msg73 => CommercialServiceEn.messages.providerRejected;
  static String get providerRejected => msg73;

  /// Traveler cancels a pending request (detailed UC-31 Alternative Flow).
  static String get msg74 => CommercialServiceEn.messages.requestCancelled;
  static String get requestCancelled => msg74;

  /// Service is not currently open for booking (detailed UC-31 Abnormal Case 7.a3).
  static String get msg75 => CommercialServiceEn.messages.serviceClosed;
  static String get serviceClosed => msg75;

  /// Requested booking date is in the past (detailed UC-31 Abnormal Case 2.a1).
  static String get msg76 => CommercialServiceEn.messages.requestedDatePast;
  static String get requestedDatePast => msg76;

  /// Access denied / permission restriction.
  static String get msg126 => CommercialServiceEn.messages.permissionDenied;
  static String get permissionDenied => msg126;

  /// Generic system or network failure (detailed UC-31 Abnormal Case 8.a1).
  static String get msg127 => CommercialServiceEn.messages.systemError;
  static String get systemError => msg127;

  /// Ordinary POI without commercial booking capabilities.
  static String get ordinaryPoiNoBooking =>
      CommercialServiceEn.messages.ordinaryPoiNoBooking;
}
