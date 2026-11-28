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
  testWidgets('invalid contact shows inline errors before booking submission', (
    tester,
  ) async {
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
    for (final entry in {
      'booking-lead-full-name': '',
      'booking-lead-phone': '123',
      'booking-lead-email': 'wrong-email',
    }.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    cubit.setAgreedToTerms(true);
    await tester.pumpAndSettle();
    expect(cubit.state.canAttemptSubmit, isTrue);
    final submit = find.widgetWithText(FilledButton, 'Xác nhận đặt tour');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    for (final entry in {
      'booking-lead-full-name': 'Vui lòng nhập họ và tên.',
      'booking-lead-phone':
          'Số điện thoại phải gồm 10 chữ số và bắt đầu bằng số 0.',
      'booking-lead-email': 'Vui lòng nhập địa chỉ email hợp lệ.',
    }.entries) {
      expect(
        tester
            .widget<TextField>(find.byKey(Key(entry.key)))
            .decoration!
            .errorText,
        entry.value,
      );
    }
    expect(repository.createCalls, isEmpty);
    final phone = find.byKey(const Key('booking-lead-phone'));
    await tester.ensureVisible(phone);
    await tester.enterText(phone, '09 123456789');
    expect(cubit.state.leadPhone, '0912345678');
    await tester.pump();
    expect(tester.widget<TextField>(phone).decoration!.errorText, isNull);
  });
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

      expect(find.text('Đặt tour'), findsOneWidget);
      expect(find.text('Áp dụng'), findsOneWidget);
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
