import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/create_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/get_booking_contact_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/quote_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking/presentation/pages/book_tour_page.dart';

import '../../booking_fakes.dart';

void main() {
  testWidgets(
    'renders the booking form without an unbounded-width layout error',
    (tester) async {
      final repository = FakeBookingRepository();
      final cubit = BookTourCubit(
        tourScheduleId: '123',
        quoteBooking: QuoteBookingUseCase(repository),
        createBooking: CreateBookingUseCase(repository),
        getBookingContact: GetBookingContactUseCase(repository),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider.value(value: cubit, child: const BookTourPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Book Tour'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prefills editable lead contact fields from the traveler profile',
    (tester) async {
      final repository = FakeBookingRepository();
      final cubit = BookTourCubit(
        tourScheduleId: '123',
        quoteBooking: QuoteBookingUseCase(repository),
        createBooking: CreateBookingUseCase(repository),
        getBookingContact: GetBookingContactUseCase(repository),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider.value(value: cubit, child: const BookTourPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('booking-lead-full-name')))
            .controller!
            .text,
        'Nguyen Van A',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('booking-lead-phone')))
            .controller!
            .text,
        '0912345678',
      );

      await tester.enterText(find.byKey(const Key('booking-lead-phone')), '');
      expect(cubit.state.leadPhone, isEmpty);
    },
  );
}
