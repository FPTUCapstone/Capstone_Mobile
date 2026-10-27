import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/datasources/demo_operator_bookings_data.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

/// DEMO-ONLY repository (debug builds with the explicit demo flag). It answers like the UC-40 backend over
/// fixed fixtures and is never a fallback for a failed live call.
final class DemoOperatorBookingsRepository
    implements OperatorBookingsRepository {
  const DemoOperatorBookingsRepository();

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) async {
    final matching =
        demoOperatorBookings
            .where((booking) => _matches(booking, query))
            .toList()
          ..sort((a, b) {
            final byBooked = b.bookedAtUtc.compareTo(a.bookedAtUtc);
            return byBooked != 0
                ? byBooked
                : int.parse(b.bookingId).compareTo(int.parse(a.bookingId));
          });

    // The same basis as the backend: every status in the count, only Confirmed and Completed travel.
    final travelling = matching.where(
      (booking) =>
          booking.status == OperatorBookingStatus.confirmed ||
          booking.status == OperatorBookingStatus.completed,
    );
    final summary = OperatorBookingsSummary(
      totalBookings: matching.length,
      totalParticipants: travelling.fold(0, (sum, b) => sum + b.quantity),
      totalConfirmedAmount: travelling.fold(0, (sum, b) => sum + b.totalAmount),
    );

    final start = (query.page - 1) * query.pageSize;
    final items = matching
        .skip(start)
        .take(query.pageSize)
        .map(_listItem)
        .toList(growable: false);
    return OperatorBookingsPage(
      items: items,
      summary: summary,
      page: query.page,
      pageSize: query.pageSize,
      totalCount: matching.length,
      totalPages: (matching.length / query.pageSize).ceil(),
    );
  }

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) async {
    for (final booking in demoOperatorBookings) {
      if (booking.bookingId == bookingId) return booking;
    }
    throw const NotFoundFailure();
  }

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() async =>
      demoOperatorBookingTourOptions;

  static bool _matches(
    OperatorBookingDetail booking,
    OperatorBookingsQuery query,
  ) {
    if (query.tourId != null && booking.tour.tourId != query.tourId) {
      return false;
    }
    if (query.status != null && booking.status != query.status) return false;

    // Departure days are Vietnam-time calendar days, both bounds inclusive.
    final day = TripFormatters.toVietnamCalendarDay(
      booking.schedule.startAtUtc,
    );
    final from = query.departureFrom;
    final to = query.departureTo;
    if (from != null && day.isBefore(from)) return false;
    if (to != null && day.isAfter(to)) return false;

    final keyword = query.keyword?.trim().toLowerCase();
    if (keyword != null && keyword.isNotEmpty) {
      return booking.bookingCode.toLowerCase().contains(keyword) ||
          booking.booker.fullName.toLowerCase().contains(keyword) ||
          (booking.booker.email ?? '').toLowerCase().contains(keyword);
    }
    return true;
  }

  static OperatorBookingListItem _listItem(OperatorBookingDetail booking) =>
      OperatorBookingListItem(
        bookingId: booking.bookingId,
        bookingCode: booking.bookingCode,
        tour: booking.tour,
        schedule: OperatorBookingSchedule(
          scheduleId: booking.schedule.scheduleId,
          startAtUtc: booking.schedule.startAtUtc,
          endAtUtc: booking.schedule.endAtUtc,
        ),
        booker: OperatorBookingBooker(
          userId: booking.booker.userId,
          fullName: booking.booker.fullName,
          email: booking.booker.email,
        ),
        quantity: booking.quantity,
        totalAmount: booking.totalAmount,
        discountAmount: booking.discountAmount,
        status: booking.status,
        paymentStatus: booking.paymentStatus,
        checkInStatus: booking.checkInStatus,
        checkedInAtUtc: booking.checkedInAtUtc,
        bookedAtUtc: booking.bookedAtUtc,
      );
}
