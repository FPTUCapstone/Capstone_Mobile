import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/operator_bookings_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';

/// The canonical copy for a UC-40 failure. Only this text ever reaches the screen, never a server body or
/// an exception message; [canRetry] is false when asking again cannot change the answer.
final class OperatorBookingFailureCopy {
  const OperatorBookingFailureCopy(this.message, {required this.canRetry});

  final String message;
  final bool canRetry;

  static OperatorBookingFailureCopy of(Object error) => switch (error) {
    // MSG126: not signed in as an approved operator, or the booking is not theirs.
    AuthenticationFailure() ||
    PermissionFailure() ||
    NotFoundFailure() => const OperatorBookingFailureCopy(
      OperatorBookingsStringsEn.accessDenied,
      canRetry: false,
    ),
    // MSG31: the backend rejected an inverted departure range.
    ValidationFailure(message: operatorBookingInvalidDateRange) =>
      const OperatorBookingFailureCopy(
        OperatorBookingsStringsEn.dateRangeInvalid,
        canRetry: false,
      ),
    // MSG127: network, server or an unreadable body.
    _ => const OperatorBookingFailureCopy(
      OperatorBookingsStringsEn.systemError,
      canRetry: true,
    ),
  };
}
