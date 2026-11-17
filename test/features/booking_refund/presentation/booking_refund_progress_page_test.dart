import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/repositories/booking_refund_repository.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/usecases/get_booking_refund_progress_use_case.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/pages/booking_refund_progress_page.dart';

void main() {
  for (final entry in {
    'PendingOperatorConfirmation': 'Awaiting confirmation',
    'AwaitingPartnerReturn': 'Awaiting partner return',
    'ReturnReported': 'Partner return reported',
    'ReturnReceived': 'Partner return received',
    'Pending': 'Refund requested',
    'Reconciliation': 'Under reconciliation',
    'Escalated': 'Escalated for review',
  }.entries) {
    testWidgets('renders ${entry.key} without claiming completion', (
      tester,
    ) async {
      final cubit = BookingRefundProgressCubit(
        getProgress: GetBookingRefundProgressUseCase(_Repository(entry.key)),
      );
      addTearDown(cubit.close);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(
            home: BookingRefundProgressPage(bookingId: '1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entry.value.toUpperCase()), findsOneWidget);
      expect(find.text('BK-DN-001'), findsOneWidget);
      expect(find.text('REFUND COMPLETED'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
      expect(find.text('Try again'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

final class _Repository implements BookingRefundRepository {
  const _Repository(this.status);
  final String status;

  @override
  Future<BookingRefundProgress> getProgress(String bookingId) async =>
      BookingRefundProgress(
        bookingId: 1,
        bookingCode: 'BK-DN-001',
        refundAmount: 500000,
        status: BookingRefundStatus.tryFromWire(status)!,
        attemptCount: 0,
        requestedAtUtc: DateTime.utc(2026, 11, 16),
      );
}
