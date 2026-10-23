import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_contact.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/create_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/get_booking_contact_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/quote_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_state.dart';
import 'package:uuid/uuid.dart';

/// UC-27 Book Tour. BR-63: this Cubit never computes price itself — every amount in
/// [BookTourState.quote] and [BookTourState.createdBooking] is read verbatim from the
/// Backend response. UC-27 ends at a created PendingPayment booking; payment (UC-28) is a
/// separate, user-initiated step this Cubit never starts.
final class BookTourCubit extends Cubit<BookTourState> {
  BookTourCubit({
    required String tourScheduleId,
    required QuoteBookingUseCase quoteBooking,
    required CreateBookingUseCase createBooking,
    required GetBookingContactUseCase getBookingContact,
  }) : _tourScheduleId = tourScheduleId,
       _quoteBooking = quoteBooking,
       _createBooking = createBooking,
       _getBookingContact = getBookingContact,
       super(const BookTourState()) {
    _requestQuote();
    _loadBookingContact();
  }

  final String _tourScheduleId;
  final QuoteBookingUseCase _quoteBooking;
  final CreateBookingUseCase _createBooking;
  final GetBookingContactUseCase _getBookingContact;

  Timer? _debounce;
  int _quoteGeneration = 0;
  String? _pendingIdempotencyKey;
  String? _pendingPayload;

  void updateParticipantCounts(ParticipantCounts counts) {
    emit(state.copyWith(participantCounts: counts));
    _scheduleQuote();
  }

  void updateLeadFullName(String value) =>
      emit(state.copyWith(leadFullName: value));

  void updateLeadPhone(String value) => emit(state.copyWith(leadPhone: value));

  void updateLeadEmail(String value) => emit(state.copyWith(leadEmail: value));

  void setAgreedToTerms(bool value) =>
      emit(state.copyWith(agreedToTerms: value));

  /// A profile lookup is only a convenience. Its failure must never prevent a
  /// Traveler from completing the form manually, and it must not overwrite a
  /// field they have already edited while the request was in flight.
  Future<void> _loadBookingContact() async {
    try {
      final contact = await _getBookingContact();
      if (isClosed) return;
      _prefillBlankContactFields(contact);
    } on Failure {
      // Leave the form empty and usable when a profile is unavailable.
    }
  }

  void _prefillBlankContactFields(BookingContact contact) {
    final fullName = state.leadFullName.trim().isEmpty
        ? contact.fullName
        : state.leadFullName;
    final phone = state.leadPhone.trim().isEmpty
        ? (contact.phoneNumber ?? '')
        : state.leadPhone;
    final email = state.leadEmail.trim().isEmpty
        ? (contact.email ?? '')
        : state.leadEmail;
    emit(
      state.copyWith(
        leadFullName: fullName,
        leadPhone: phone,
        leadEmail: email,
      ),
    );
  }

  /// Stages a voucher code; the next quote tells the user whether it was accepted (BR-63 —
  /// this Cubit never decides eligibility itself).
  void applyVoucherCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    emit(
      normalized == null || normalized.isEmpty
          ? state.copyWith(clearVoucherCode: true)
          : state.copyWith(voucherCode: normalized),
    );
    _scheduleQuote();
  }

  void _scheduleQuote() {
    _debounce?.cancel();
    if (state.participantCounts.total == 0) {
      emit(state.copyWith(clearQuote: true, quoteStatus: QuoteStatus.idle));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _requestQuote);
  }

  Future<void> _requestQuote() async {
    final generation = ++_quoteGeneration;
    emit(
      state.copyWith(quoteStatus: QuoteStatus.loading, clearQuoteFailure: true),
    );
    try {
      final quote = await _quoteBooking(
        tourScheduleId: _tourScheduleId,
        participantCounts: state.participantCounts,
        voucherCode: state.voucherCode,
      );
      if (isClosed || generation != _quoteGeneration) return;
      emit(state.copyWith(quoteStatus: QuoteStatus.ready, quote: quote));
    } on Failure catch (failure) {
      if (isClosed || generation != _quoteGeneration) return;
      emit(
        state.copyWith(
          quoteStatus: QuoteStatus.failure,
          quoteFailure: failure,
          clearQuote: true,
        ),
      );
    }
  }

  List<BookingParticipant> _buildParticipants() {
    final counts = state.participantCounts;
    final lead = BookingParticipant(
      fullName: state.leadFullName.trim(),
      participantType: ParticipantType.adult,
      phoneNumber: state.leadPhone.trim(),
      email: state.leadEmail.trim().isEmpty ? null : state.leadEmail.trim(),
    );
    return [
      lead,
      for (var i = 1; i < counts.adult; i++)
        BookingParticipant(
          fullName: 'Adult ${i + 1}',
          participantType: ParticipantType.adult,
        ),
      for (var i = 0; i < counts.child; i++)
        BookingParticipant(
          fullName: 'Child ${i + 1}',
          participantType: ParticipantType.child,
        ),
      for (var i = 0; i < counts.infant; i++)
        BookingParticipant(
          fullName: 'Infant ${i + 1}',
          participantType: ParticipantType.infant,
        ),
    ];
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.submitting,
        clearSubmitFailure: true,
      ),
    );

    final participants = _buildParticipants();
    // Same payload retried after a lost response reuses its key, so the server replays the
    // original booking; any edited intent (different counts, lead info, or voucher) starts
    // a new one.
    final payload = jsonEncode({
      'tourScheduleId': _tourScheduleId,
      'participants': [for (final p in participants) p.toJson()],
      'voucherCode': state.voucherCode,
    });
    if (_pendingPayload != payload) {
      _pendingPayload = payload;
      _pendingIdempotencyKey = const Uuid().v4();
    }

    try {
      final booking = await _createBooking(
        tourScheduleId: _tourScheduleId,
        participants: participants,
        idempotencyKey: _pendingIdempotencyKey!,
        voucherCode: state.voucherCode,
      );
      _pendingIdempotencyKey = null;
      _pendingPayload = null;
      if (!isClosed) {
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.success,
            createdBooking: booking,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.failure,
            submitFailure: failure,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
