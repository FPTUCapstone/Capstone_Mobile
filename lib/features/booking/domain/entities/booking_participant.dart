import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';

/// One named ticket-holder submitted to POST /api/v1/traveler/tour-bookings (UC-27 spec §3).
/// `idDocumentNumber` is PII — the Backend encrypts it before persistence; this entity only
/// ever carries the plaintext value entered by the Traveler, in memory, for one submission.
final class BookingParticipant extends Equatable {
  const BookingParticipant({
    required this.fullName,
    required this.participantType,
    this.phoneNumber,
    this.email,
    this.idDocumentType,
    this.idDocumentNumber,
    this.nationality,
  });

  final String fullName;
  final ParticipantType participantType;
  final String? phoneNumber;
  final String? email;
  final String? idDocumentType;
  final String? idDocumentNumber;
  final String? nationality;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'participantType': participantType.toWire(),
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (email != null) 'email': email,
    if (idDocumentType != null) 'idDocumentType': idDocumentType,
    if (idDocumentNumber != null) 'idDocumentNumber': idDocumentNumber,
    if (nationality != null) 'nationality': nationality,
  };

  /// Returns a copy with the document fields cleared. Called after a successful create so the
  /// in-memory form state never keeps PII longer than one submission (spec §4).
  BookingParticipant withoutDocument() => BookingParticipant(
    fullName: fullName,
    participantType: participantType,
    phoneNumber: phoneNumber,
    email: email,
  );

  @override
  List<Object?> get props => [
    fullName,
    participantType,
    phoneNumber,
    email,
    idDocumentType,
    idDocumentNumber,
    nationality,
  ];
}

/// How many of each participant type the Traveler has selected. Sent to the quote endpoint as
/// counts; the create endpoint instead receives one [BookingParticipant] per person.
final class ParticipantCounts extends Equatable {
  const ParticipantCounts({this.adult = 1, this.child = 0, this.infant = 0});

  final int adult;
  final int child;
  final int infant;

  int get total => adult + child + infant;

  ParticipantCounts copyWith({int? adult, int? child, int? infant}) =>
      ParticipantCounts(
        adult: adult ?? this.adult,
        child: child ?? this.child,
        infant: infant ?? this.infant,
      );

  Map<String, dynamic> toJson() => {
    'adult': adult,
    'child': child,
    'infant': infant,
  };

  @override
  List<Object?> get props => [adult, child, infant];
}
