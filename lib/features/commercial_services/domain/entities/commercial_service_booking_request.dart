import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';

import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';

/// Canonical lifecycle statuses of a commercial service booking request
/// (`Report 3 SRS Section 3.6.2`, `BR-89`, `PC-01`).
///
/// `BR-89` (detailed UC-31): A commercial service booking request is created with the status
/// `Pending Confirmation` and becomes `Confirmed` only after the commercial
/// service provider has confirmed it; the submission of a request alone never
/// guarantees the service.
enum CommercialBookingStatus {
  pendingConfirmation('Pending Confirmation'),
  confirmed('Confirmed'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const CommercialBookingStatus(this.canonicalLabel);

  final String canonicalLabel;

  String get localizedLabel => switch (this) {
    CommercialBookingStatus.pendingConfirmation =>
      CommercialServiceEn.booking.statusPendingConfirmation,
    CommercialBookingStatus.confirmed =>
      CommercialServiceEn.booking.statusConfirmed,
    CommercialBookingStatus.rejected =>
      CommercialServiceEn.booking.statusRejected,
    CommercialBookingStatus.cancelled =>
      CommercialServiceEn.booking.statusCancelled,
  };
}

/// Traveler contact information group for UC-31 (`Contact Full Name`,
/// `Contact Phone Number`, `Contact Email`).
final class CommercialBookingContactInfo extends Equatable {
  const CommercialBookingContactInfo({
    required this.fullName,
    required this.phoneNumber,
    required this.email,
  });

  final String fullName;
  final String phoneNumber;
  final String email;

  @override
  List<Object?> get props => [fullName, phoneNumber, email];
}

/// Represents a commercial service booking request in UC-31 (`3.6.2`).
final class CommercialServiceBookingRequest extends Equatable {
  const CommercialServiceBookingRequest({
    required this.requestId,
    required this.poiId,
    required this.serviceName,
    required this.category,
    required this.selectedOption,
    required this.requestedDateIso,
    required this.requestedTime,
    required this.quantity,
    required this.contactInfo,
    required this.estimatedAmountVnd,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.address,
    this.specialRequest,
    this.associatedItinerarySummary,
    this.refundChannelNotice,
  });

  final String requestId;
  final int poiId;
  final String serviceName;
  final CommercialServiceCategory category;
  final String? address;
  final CommercialServiceOption selectedOption;
  final String requestedDateIso;
  final String requestedTime;
  final int quantity;
  final String? specialRequest;
  final CommercialBookingContactInfo contactInfo;

  /// `BR-63`: The estimated amount of the request is computed by TripMate from
  /// the price information of the service; an amount submitted by the client
  /// application is ignored. In Demo mode, this value is explicitly labeled as
  /// a Demo preview amount.
  final int estimatedAmountVnd;
  final CommercialBookingStatus status;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// `PC-03`: A confirmed request is reflected in the associated itinerary of
  /// the Traveler.
  final String? associatedItinerarySummary;

  /// `BR-76` / `PC-05`: When a payment has been collected for a commercial
  /// service booking, any refund is returned through the original payment
  /// channel.
  final String? refundChannelNotice;

  CommercialServiceBookingRequest copyWith({
    CommercialBookingStatus? status,
    DateTime? updatedAtUtc,
    String? associatedItinerarySummary,
    String? refundChannelNotice,
  }) {
    return CommercialServiceBookingRequest(
      requestId: requestId,
      poiId: poiId,
      serviceName: serviceName,
      category: category,
      address: address,
      selectedOption: selectedOption,
      requestedDateIso: requestedDateIso,
      requestedTime: requestedTime,
      quantity: quantity,
      specialRequest: specialRequest,
      contactInfo: contactInfo,
      estimatedAmountVnd: estimatedAmountVnd,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      associatedItinerarySummary:
          associatedItinerarySummary ?? this.associatedItinerarySummary,
      refundChannelNotice: refundChannelNotice ?? this.refundChannelNotice,
    );
  }

  @override
  List<Object?> get props => [
    requestId,
    poiId,
    serviceName,
    category,
    address,
    selectedOption,
    requestedDateIso,
    requestedTime,
    quantity,
    specialRequest,
    contactInfo,
    estimatedAmountVnd,
    status,
    createdAtUtc,
    updatedAtUtc,
    associatedItinerarySummary,
    refundChannelNotice,
  ];
}
