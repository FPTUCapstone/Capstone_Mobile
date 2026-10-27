import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_bookings/utils/operator_booking_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

void main() {
  group('formatVnd', () {
    test('writes whole dong with thousands separators', () {
      expect(OperatorBookingFormatters.formatVnd(2400000), '2,400,000 VND');
      expect(OperatorBookingFormatters.formatVnd(98400000), '98,400,000 VND');
      expect(OperatorBookingFormatters.formatVnd(1000), '1,000 VND');
      expect(OperatorBookingFormatters.formatVnd(999), '999 VND');
    });

    test('zero is 0 VND, never "Free"', () {
      expect(OperatorBookingFormatters.formatVnd(0), '0 VND');
      expect(OperatorBookingFormatters.formatVnd(0), isNot(contains('Free')));
    });

    test('rounds a decimal amount to the nearest whole dong', () {
      expect(OperatorBookingFormatters.formatVnd(2399999.5), '2,400,000 VND');
      expect(OperatorBookingFormatters.formatVnd(2399999.4), '2,399,999 VND');
      expect(OperatorBookingFormatters.formatVnd(0.4), '0 VND');
      expect(OperatorBookingFormatters.formatVnd(2400000.00), '2,400,000 VND');
    });
  });

  group('dates (CR-07: dd/MM/yyyy in Asia/Ho_Chi_Minh)', () {
    test('a UTC instant moves to the Vietnam day', () {
      expect(
        OperatorBookingFormatters.date(DateTime.utc(2026, 11, 1, 16, 59)),
        '01/11/2026',
      );
      expect(
        OperatorBookingFormatters.date(DateTime.utc(2026, 11, 1, 17)),
        '02/11/2026',
      );
    });

    test('date and time use a 24-hour clock in UTC+7', () {
      expect(
        OperatorBookingFormatters.dateTime(DateTime.utc(2026, 10, 20, 3, 15)),
        '20/10/2026 10:15',
      );
    });
  });

  group('labels and badges', () {
    test('every booking status has a label and a badge, incl. Expired', () {
      final labels = {
        for (final status in OperatorBookingStatus.values)
          status: OperatorBookingFormatters.statusLabel(status),
      };

      expect(
        labels.values.toSet(),
        hasLength(OperatorBookingStatus.values.length),
      );
      expect(
        labels[OperatorBookingStatus.expired],
        OperatorBookingsStringsEn.statusExpired,
      );
      expect(
        OperatorBookingFormatters.statusBadge(OperatorBookingStatus.confirmed),
        StatusBadgeType.success,
      );
      expect(
        OperatorBookingFormatters.statusBadge(
          OperatorBookingStatus.pendingPayment,
        ),
        StatusBadgeType.warning,
      );
      expect(
        OperatorBookingFormatters.statusBadge(OperatorBookingStatus.cancelled),
        StatusBadgeType.error,
      );
      expect(
        OperatorBookingFormatters.statusBadge(OperatorBookingStatus.completed),
        StatusBadgeType.info,
      );
      expect(
        OperatorBookingFormatters.statusBadge(OperatorBookingStatus.expired),
        StatusBadgeType.neutral,
      );
    });

    test(
      'payment status, check-in, participant type, gateway and ticket are all readable',
      () {
        for (final value in OperatorPaymentStatus.values) {
          expect(
            OperatorBookingFormatters.paymentStatusLabel(value),
            isNotEmpty,
          );
        }
        for (final value in OperatorCheckInStatus.values) {
          expect(OperatorBookingFormatters.checkInLabel(value), isNotEmpty);
        }
        for (final value in OperatorParticipantType.values) {
          expect(
            OperatorBookingFormatters.participantTypeLabel(value),
            isNotEmpty,
          );
        }
        for (final value in OperatorPaymentGateway.values) {
          expect(OperatorBookingFormatters.gatewayLabel(value), isNotEmpty);
        }
        for (final value in OperatorTicketStatus.values) {
          expect(
            OperatorBookingFormatters.ticketStatusLabel(value),
            isNotEmpty,
          );
        }
        expect(
          OperatorBookingFormatters.checkInLabel(
            OperatorCheckInStatus.checkedIn,
          ),
          isNot(
            OperatorBookingFormatters.checkInLabel(
              OperatorCheckInStatus.notCheckedIn,
            ),
          ),
        );
        expect(
          OperatorBookingFormatters.checkInBadge(
            OperatorCheckInStatus.checkedIn,
          ),
          StatusBadgeType.success,
        );
        expect(
          OperatorBookingFormatters.checkInBadge(
            OperatorCheckInStatus.notCheckedIn,
          ),
          StatusBadgeType.neutral,
        );
      },
    );

    test('no user-facing label shows an internal message id', () {
      final strings = [
        OperatorBookingsStringsEn.accessDenied,
        OperatorBookingsStringsEn.systemError,
        OperatorBookingsStringsEn.noRecords,
        OperatorBookingsStringsEn.dateRangeInvalid,
      ];
      for (final text in strings) {
        expect(text, isNot(matches(RegExp(r'MSG\d+'))));
        expect(text, isNot(contains('PENDING_BE_INTEGRATION')));
      }
    });
  });
}
