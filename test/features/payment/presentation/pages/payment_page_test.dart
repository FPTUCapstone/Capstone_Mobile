import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/cancel_payment_use_case.dart';
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
      cancelPayment: CancelPaymentUseCase(repository),
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

  testWidgets('shows the native banking-app action when PayOS provides VietQR', (
    tester,
  ) async {
    final repository = FakePaymentRepository(
      qrCode:
          '00020101021238570010A00000072701270006970436011308810004555550208QRIBFTTA530370454061500005802VN6304TEST',
    );
    final cubit = PaymentCubit(
      createOrReusePayment: CreateOrReusePaymentUseCase(repository),
      getBookingPaymentStatus: GetBookingPaymentStatusUseCase(repository),
      completeMockPayment: CompleteMockPaymentUseCase(repository),
      cancelPayment: CancelPaymentUseCase(repository),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const PaymentPage(bookingId: 'booking-test-id'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Quét VietQR để thanh toán'), findsOneWidget);
    expect(find.text('Mở ứng dụng ngân hàng'), findsOneWidget);
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
      cancelPayment: CancelPaymentUseCase(repository),
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

  testWidgets(
    'the paid view opens the e-ticket of the booking and never leaves by itself',
    (tester) async {
      final repository = FakePaymentRepository(
        initialBookingStatus: 'Confirmed',
        initialPaymentStatus: 'Paid',
      );
      final cubit = PaymentCubit(
        createOrReusePayment: CreateOrReusePaymentUseCase(repository),
        getBookingPaymentStatus: GetBookingPaymentStatusUseCase(repository),
        completeMockPayment: CompleteMockPaymentUseCase(repository),
        cancelPayment: CancelPaymentUseCase(repository),
      );
      addTearDown(cubit.close);
      final visited = <String>[];
      final router = GoRouter(
        initialLocation: '/payment/456',
        routes: [
          GoRoute(
            path: '/payment/:bookingId',
            builder: (_, state) => BlocProvider.value(
              value: cubit,
              child: PaymentPage(
                bookingId: state.pathParameters['bookingId']!,
                initialBookingCode: 'BK-TEST',
                initialAmount: 1500000,
                initialCurrency: 'VND',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.bookingETicketPattern,
            builder: (_, state) {
              visited.add(state.uri.path);
              return const Scaffold(body: Text('E-ticket stub'));
            },
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, state) {
              visited.add(state.uri.path);
              return const Scaffold(body: Text('Home stub'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(find.text('Thanh Toán Thành Công!'), findsOneWidget);
      expect(find.textContaining('Tự động trở về'), findsNothing);
      expect(visited, isEmpty);

      await tester.tap(find.text('Xem vé điện tử'));
      await tester.pumpAndSettle();

      expect(visited, [AppRoutes.bookingETicket(456)]);
    },
  );
}
