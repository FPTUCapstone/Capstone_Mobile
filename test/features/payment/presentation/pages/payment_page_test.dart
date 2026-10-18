import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/complete_mock_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/create_or_reuse_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/get_booking_payment_status_use_case.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_cubit.dart';
import 'package:trip_mate_mobile/features/payment/presentation/pages/payment_page.dart';

import '../../payment_fakes.dart';

void main() {
  testWidgets('renders PaymentPage and displays pending payment information', (
    tester,
  ) async {
    final repository = FakePaymentRepository();
    final cubit = PaymentCubit(
      createOrReusePayment: CreateOrReusePaymentUseCase(repository),
      getBookingPaymentStatus: GetBookingPaymentStatusUseCase(repository),
      completeMockPayment: CompleteMockPaymentUseCase(repository),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const PaymentPage(
            bookingId: 'booking-test-id',
            initialBookingCode: 'BK-TEST',
            initialAmount: 1500000,
            initialCurrency: 'VND',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Thanh Toán Điện Tử'), findsOneWidget);
    expect(find.text('MÃ ĐẶT TOUR'), findsOneWidget);
    expect(find.text('BK-TEST'), findsWidgets);
    expect(find.text('1.500.000₫'), findsWidgets);
  });

  testWidgets('displays success view when booking is confirmed', (
    tester,
  ) async {
    final repository = FakePaymentRepository(
      initialBookingStatus: 'Confirmed',
      initialPaymentStatus: 'Paid',
    );
    final cubit = PaymentCubit(
      createOrReusePayment: CreateOrReusePaymentUseCase(repository),
      getBookingPaymentStatus: GetBookingPaymentStatusUseCase(repository),
      completeMockPayment: CompleteMockPaymentUseCase(repository),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const PaymentPage(
            bookingId: 'booking-test-id',
            initialBookingCode: 'BK-TEST',
            initialAmount: 1500000,
            initialCurrency: 'VND',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Thanh Toán Thành Công!'), findsOneWidget);
    expect(find.textContaining('hoàn tất thanh toán'), findsOneWidget);
  });
}
