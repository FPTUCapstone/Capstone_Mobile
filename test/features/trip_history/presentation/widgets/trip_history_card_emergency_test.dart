import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_history_card.dart';

void main() {
  BookingTripRecord booking(String status, TripStatus tab) => BookingTripRecord(
    id: 42,
    tab: tab,
    title: 'Hue heritage day tour',
    departureAtUtc: DateTime.utc(2026, 11, 10),
    status: status,
    actions: const TripRecordActions(
      canReview: false,
      canViewETicket: false,
      ticketId: null,
      canViewRefund: false,
    ),
    bookingCode: 'BK-1',
    participantCount: 3,
    totalAmount: 1000000,
    reviewableRecord: const ReviewableRecordRef(
      kind: ReviewableRecordKind.commerceBooking,
      id: 42,
    ),
    review: const TripRecordReview(exists: false),
  );

  Future<void> pump(
    WidgetTester tester,
    TripRecord record, {
    ValueChanged<BookingTripRecord>? onViewEmergencyNotice,
    bool hasEmergencyNotice = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TripHistoryCard(
            record: record,
            onViewEticket: (_) {},
            onWriteReview: (_) {},
            onViewReview: (_) {},
            onViewRefund: (_) {},
            onViewDetails: (_) {},
            onViewEmergencyNotice: onViewEmergencyNotice,
            hasEmergencyNotice: hasEmergencyNotice,
          ),
        ),
      ),
    ),
  );

  testWidgets('a stopped tour is not labelled as cancelled', (tester) async {
    Finder label(String text) =>
        find.textContaining(RegExp(text, caseSensitive: false));

    await pump(tester, booking('Interrupted', TripStatus.cancelled));
    expect(label('đã dừng vì an toàn'), findsOneWidget);
    expect(label('cancelled'), findsNothing);

    await pump(tester, booking('Cancelled', TripStatus.cancelled));
    expect(label('cancelled'), findsOneWidget);
  });

  for (final status in ['Cancelled', 'Interrupted']) {
    testWidgets('a $status booking opens its emergency notice', (tester) async {
      BookingTripRecord? opened;
      await pump(
        tester,
        booking(status, TripStatus.cancelled),
        onViewEmergencyNotice: (record) => opened = record,
      );

      await tester.tap(find.byKey(const Key('trip-emergency-notice')));

      expect(opened?.reviewableRecord.id, 42);
    });
  }

  testWidgets('an ordinary cancellation has no emergency action', (
    tester,
  ) async {
    await pump(
      tester,
      booking('Cancelled', TripStatus.cancelled),
      onViewEmergencyNotice: (_) {},
      hasEmergencyNotice: false,
    );

    expect(find.byKey(const Key('trip-emergency-notice')), findsNothing);
  });

  testWidgets('demo records have no emergency action', (tester) async {
    await pump(tester, booking('Cancelled', TripStatus.cancelled));

    expect(find.byKey(const Key('trip-emergency-notice')), findsNothing);
  });
}
