import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';

enum QuoteStatus { idle, loading, ready, failure }

enum SubmitStatus { idle, submitting, success, failure }

final class BookTourState extends Equatable {
  const BookTourState({
    this.participantCounts = const ParticipantCounts(),
    this.voucherCode,
    this.leadFullName = '',
    this.leadPhone = '',
    this.leadEmail = '',
    this.agreedToTerms = false,
    this.quoteStatus = QuoteStatus.idle,
    this.quote,
    this.quoteFailure,
    this.submitStatus = SubmitStatus.idle,
    this.createdBooking,
    this.submitFailure,
  });

  final ParticipantCounts participantCounts;
  final String? voucherCode;
  final String leadFullName;
  final String leadPhone;
  final String leadEmail;
  final bool agreedToTerms;

  final QuoteStatus quoteStatus;
  final BookingQuote? quote;
  final Failure? quoteFailure;

  final SubmitStatus submitStatus;
  final TourBooking? createdBooking;
  final Failure? submitFailure;

  bool get hasValidQuote =>
      quoteStatus == QuoteStatus.ready &&
      quote != null &&
      quote!.participantCounts == participantCounts;

  bool get canSubmit =>
      hasValidQuote &&
      agreedToTerms &&
      leadPhone.trim().isNotEmpty &&
      submitStatus != SubmitStatus.submitting;

  BookTourState copyWith({
    ParticipantCounts? participantCounts,
    String? voucherCode,
    bool clearVoucherCode = false,
    String? leadFullName,
    String? leadPhone,
    String? leadEmail,
    bool? agreedToTerms,
    QuoteStatus? quoteStatus,
    BookingQuote? quote,
    bool clearQuote = false,
    Failure? quoteFailure,
    bool clearQuoteFailure = false,
    SubmitStatus? submitStatus,
    TourBooking? createdBooking,
    Failure? submitFailure,
    bool clearSubmitFailure = false,
  }) => BookTourState(
    participantCounts: participantCounts ?? this.participantCounts,
    voucherCode: clearVoucherCode ? null : (voucherCode ?? this.voucherCode),
    leadFullName: leadFullName ?? this.leadFullName,
    leadPhone: leadPhone ?? this.leadPhone,
    leadEmail: leadEmail ?? this.leadEmail,
    agreedToTerms: agreedToTerms ?? this.agreedToTerms,
    quoteStatus: quoteStatus ?? this.quoteStatus,
    quote: clearQuote ? null : (quote ?? this.quote),
    quoteFailure: clearQuoteFailure
        ? null
        : (quoteFailure ?? this.quoteFailure),
    submitStatus: submitStatus ?? this.submitStatus,
    createdBooking: createdBooking ?? this.createdBooking,
    submitFailure: clearSubmitFailure
        ? null
        : (submitFailure ?? this.submitFailure),
  );

  @override
  List<Object?> get props => [
    participantCounts,
    voucherCode,
    leadFullName,
    leadPhone,
    leadEmail,
    agreedToTerms,
    quoteStatus,
    quote,
    quoteFailure,
    submitStatus,
    createdBooking,
    submitFailure,
  ];
}
