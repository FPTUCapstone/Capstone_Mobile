import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';

/// UC-29 copy. MSG numbers follow Report 3; MSG138–MSG140 come from the UC-29
/// Backend spec §8. Worded for the Traveler who views the ticket.
abstract final class ETicketStrings {
  static const title = 'E-ticket';
  static const msg93 =
      'Your encrypted QR ticket is ready. Present this code at the tour gate.';
  static String msg95(String checkedInAt) =>
      'This QR ticket was already used for check-in at $checkedInAt.';
  static String msg98(String departureDate) =>
      'This ticket is valid only on departure date: $departureDate.';
  static const msg126 = 'You do not have permission to access this function.';
  static const msg127 =
      'TripMate is temporarily unable to process your request. Please check your connection and try again.';
  static const msg138 =
      'Your e-ticket will be available once the payment for this booking is confirmed.';
  static String msg139(String bookingCode) =>
      'This e-ticket was cancelled together with booking $bookingCode and cannot be used for check-in.';
  static String msg140(String departureDate) =>
      'This e-ticket expired after the departure date $departureDate.';

  static const signIn = 'Your session has expired. Please sign in again.';
  static const notFound = 'The e-ticket was not found.';
  static const staleQr =
      'The QR code on screen may no longer work. Reload the ticket when you are back online.';
  static const offline =
      'You are offline — the QR code cannot be refreshed now.';
  static const meetingPointMissing = 'Not provided yet';
  static String validityNote(String departureDate) =>
      'Valid only on the departure date $departureDate.';

  static const refresh = 'Refresh QR code';
  static const refreshing = 'Refreshing…';
  static const refreshConfirm =
      'The current QR code will stop working. Continue?';
  static const confirmRefresh = 'Refresh';
  static const cancel = 'Cancel';
  static const retry = 'Retry';
  static const back = 'Back';

  static const ticketCode = 'Ticket code';
  static const bookingCode = 'Booking code';
  static const departure = 'Departure';
  static const meetingPoint = 'Meeting point';
  static const participants = 'Travellers';
  static const checkedInAt = 'Checked in at';

  static String statusLabel(ETicketStatus status) => switch (status) {
    ETicketStatus.notYetActive => 'Not yet active',
    ETicketStatus.valid => 'Valid',
    ETicketStatus.used => 'Used',
    ETicketStatus.cancelled => 'Cancelled',
    ETicketStatus.expired => 'Expired',
  };

  static String participantSummary(
    int adults,
    int children,
    int infants,
    int total,
  ) {
    String plural(int count, String one, String many) =>
        '$count ${count == 1 ? one : many}';
    final parts = [
      if (adults > 0) plural(adults, 'adult', 'adults'),
      if (children > 0) plural(children, 'child', 'children'),
      if (infants > 0) plural(infants, 'infant', 'infants'),
    ];
    return '${parts.join(', ')} (${plural(total, 'traveller', 'travellers')})';
  }
}
