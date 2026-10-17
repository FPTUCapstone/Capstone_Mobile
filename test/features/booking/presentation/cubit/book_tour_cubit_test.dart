import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/create_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/quote_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_state.dart';

import '../../booking_fakes.dart';

BookTourCubit _cubit(FakeBookingRepository repository) => BookTourCubit(
  tourScheduleId: '123',
  quoteBooking: QuoteBookingUseCase(repository),
  createBooking: CreateBookingUseCase(repository),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 400));

void main() {
  group('quote', () {
    test(
      'requests a quote for the initial participant counts on construction',
      () async {
        final repository = FakeBookingRepository();
        final cubit = _cubit(repository);
        addTearDown(cubit.close);

        await _settle();

        expect(repository.quoteCalls, hasLength(1));
        expect(cubit.state.quoteStatus, QuoteStatus.ready);
        expect(cubit.state.quote, isNotNull);
      },
    );

    test(
      'debounces repeated count changes into a single quote request',
      () async {
        final repository = FakeBookingRepository();
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await _settle();
        final callsBeforeChange = repository.quoteCalls.length;

        cubit.updateParticipantCounts(
          const ParticipantCounts(adult: 1, child: 1),
        );
        cubit.updateParticipantCounts(
          const ParticipantCounts(adult: 1, child: 2),
        );
        cubit.updateParticipantCounts(
          const ParticipantCounts(adult: 1, child: 3),
        );
        await _settle();

        expect(repository.quoteCalls.length, callsBeforeChange + 1);
        expect(
          repository.quoteCalls.last.$2,
          const ParticipantCounts(adult: 1, child: 3),
        );
      },
    );

    test('a quote failure is reported without crashing the cubit', () async {
      final repository = FakeBookingRepository(failQuotes: 1);
      final cubit = _cubit(repository);
      addTearDown(cubit.close);

      await _settle();

      expect(cubit.state.quoteStatus, QuoteStatus.failure);
      expect(cubit.state.quote, isNull);
    });

    test(
      'an applied voucher code is sent with the next quote request',
      () async {
        final repository = FakeBookingRepository();
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await _settle();

        cubit.applyVoucherCode('summer2026');
        await _settle();

        expect(repository.quoteCalls.last.$3, 'SUMMER2026');
        expect(cubit.state.voucherCode, 'SUMMER2026');
      },
    );
  });

  group('submit', () {
    test('cannot submit until terms are agreed and the phone is set', () async {
      final repository = FakeBookingRepository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await _settle();

      expect(cubit.state.canSubmit, isFalse);

      cubit.updateLeadFullName('Nguyen Van A');
      cubit.updateLeadPhone('0912345678');
      cubit.setAgreedToTerms(true);

      expect(cubit.state.canSubmit, isTrue);
    });

    test('a successful submit creates the booking and reports it', () async {
      final repository = FakeBookingRepository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await _settle();
      cubit.updateLeadFullName('Nguyen Van A');
      cubit.updateLeadPhone('0912345678');
      cubit.setAgreedToTerms(true);

      await cubit.submit();

      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.createdBooking?.bookingCode, 'BK-20261017-00001');
      final participants = repository.createCalls.single.$2;
      expect(participants.single.fullName, 'Nguyen Van A');
      expect(participants.single.participantType, ParticipantType.adult);
    });

    test(
      'retrying the same submission reuses the idempotency key; an edit rotates it',
      () async {
        final repository = FakeBookingRepository(failCreates: 1);
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await _settle();
        cubit.updateLeadFullName('Nguyen Van A');
        cubit.updateLeadPhone('0912345678');
        cubit.setAgreedToTerms(true);

        await cubit.submit();
        expect(cubit.state.submitStatus, SubmitStatus.failure);
        await cubit.submit();
        expect(cubit.state.submitStatus, SubmitStatus.success);
        expect(repository.createKeys[1], repository.createKeys[0]);

        cubit.updateLeadFullName('Edited Name');
        await cubit.submit();
        expect(repository.createKeys[2], isNot(repository.createKeys[1]));
      },
    );

    test(
      'does not build a participant list for a stale quote under capacity',
      () async {
        final repository = FakeBookingRepository();
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await _settle();
        cubit.updateLeadFullName('Nguyen Van A');
        cubit.updateLeadPhone('0912345678');
        cubit.setAgreedToTerms(true);

        // Changing counts invalidates the previous quote until a fresh one resolves.
        cubit.updateParticipantCounts(const ParticipantCounts(adult: 2));
        expect(cubit.state.canSubmit, isFalse);
      },
    );
  });
}
