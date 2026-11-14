import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/create_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/get_booking_contact_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/quote_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/repositories/booking_refund_repository.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/usecases/get_booking_refund_progress_use_case.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/pages/booking_refund_progress_page.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/usecases/send_support_message.dart';

import '../booking/booking_fakes.dart';
import 'support_chat_test.dart' show FakeChatRepository;

void main() {
  setUp(() async {
    await serviceLocator.reset();
  });
  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets(
    'chat booking action opens the real form with schedule and adult prefill',
    (tester) async {
      final session = AuthSessionCubit(
        null,
        _SessionStorage(UserRole.traveler),
      );
      await session.restoreSession();
      addTearDown(session.close);
      final chat = FakeChatRepository();
      final booking = FakeBookingRepository();
      serviceLocator.registerFactory<SendSupportMessage>(
        () => SendSupportMessage(chat),
      );
      serviceLocator
          .registerFactoryParam<BookTourCubit, String, ParticipantCounts?>(
            (scheduleId, counts) => BookTourCubit(
              tourScheduleId: scheduleId,
              initialParticipantCounts: counts,
              quoteBooking: QuoteBookingUseCase(booking),
              createBooking: CreateBookingUseCase(booking),
              getBookingContact: GetBookingContactUseCase(booking),
            ),
          );
      final router = createAppRouter(session);
      addTearDown(router.dispose);
      router.go(AppRoutes.supportChat);
      await tester.pumpWidget(
        BlocProvider.value(
          value: session,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.bySemanticsLabel('Message'),
        'Book for two adults',
      );
      await tester.tap(find.byTooltip('Send message'));
      chat.pending.complete(
        const SupportChatReply(
          answer: 'Review the booking details',
          sources: [],
          actions: [
            SupportChatAction(
              type: SupportChatActionType.navigate,
              label: 'Review booking',
              url: '/tours/45/book?scheduleId=123&adults=2',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Review booking'));
      await tester.pumpAndSettle();
      expect(find.text('Book Tour'), findsOneWidget);
      expect(booking.quoteCalls.single.$1, '123');
      expect(booking.quoteCalls.single.$2, const ParticipantCounts(adult: 2));
      expect(booking.quoteCalls.single.$2.total, 2);
      expect(booking.quoteCalls.single.$2.child, 0);
      expect(booking.quoteCalls.single.$2.infant, 0);
      expect(booking.createCalls, isEmpty);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm booking'),
      );
      expect(confirm.onPressed, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Review the booking details'), findsOneWidget);
      router.go(AppRoutes.bookTour('45', '123'));
      await tester.pumpAndSettle();
      router.go(AppRoutes.supportChat);
      await tester.pumpAndSettle();
      expect(find.text('Review the booking details'), findsNothing);
      expect(
        find.text('Ask about tours, bookings, refunds or itineraries.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('production chat route applies initial context and handles 401', (
    tester,
  ) async {
    final session = AuthSessionCubit(null, _SessionStorage(UserRole.traveler));
    await session.restoreSession();
    addTearDown(session.close);
    final repository = FakeChatRepository();
    serviceLocator.registerFactory<SendSupportMessage>(
      () => SendSupportMessage(repository),
    );
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    router.go(
      AppRoutes.supportChat,
      extra: const SupportChatContext(kind: 'refund', id: '42'),
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected refund #42'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Message'), 'My refund');
    await tester.tap(find.byTooltip('Send message'));
    expect(
      repository.requests.single.context,
      const SupportChatContext(kind: 'refund', id: '42'),
    );
    repository.pending.completeError(const AuthenticationFailure());
    await tester.pumpAndSettle();
    expect(session.state.isAuthenticated, isFalse);
    expect(find.text('My refund'), findsNothing);
  });

  for (final role in UserRole.values) {
    testWidgets('refund action explicitly selects booking for $role', (
      tester,
    ) async {
      final session = AuthSessionCubit(null, _SessionStorage(role));
      await session.restoreSession();
      final refund = BookingRefundProgressCubit(
        getProgress: GetBookingRefundProgressUseCase(_RefundRepository()),
      );
      addTearDown(session.close);
      addTearDown(refund.close);
      SupportChatContext? selected;
      final destination = role == UserRole.traveler
          ? AppRoutes.supportChat
          : AppRoutes.operatorSupportChat;
      final router = GoRouter(
        initialLocation: AppRoutes.bookingRefund('42'),
        routes: [
          GoRoute(
            path: AppRoutes.bookingRefundPattern,
            builder: (_, _) => BlocProvider.value(
              value: refund,
              child: const BookingRefundProgressPage(bookingId: '42'),
            ),
          ),
          GoRoute(
            path: destination,
            builder: (_, state) {
              selected = state.extra as SupportChatContext?;
              return const Scaffold(body: Text('Contextual support'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider<AuthSessionCubit>.value(
          value: session,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask about this refund'));
      await tester.pumpAndSettle();
      expect(find.text('Contextual support'), findsOneWidget);
      expect(selected, const SupportChatContext(kind: 'refund', id: '42'));
    });
  }

  for (final failure in [
    const NotFoundFailure(),
    const AuthenticationFailure(),
  ]) {
    testWidgets(
      'refund support action is hidden while loading and after $failure',
      (tester) async {
        final repository = _PendingRefundRepository();
        final cubit = BookingRefundProgressCubit(
          getProgress: GetBookingRefundProgressUseCase(repository),
        );
        addTearDown(cubit.close);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const BookingRefundProgressPage(bookingId: '42'),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Ask about this refund'), findsNothing);
        repository.result.completeError(failure);
        await tester.pumpAndSettle();
        expect(find.text('Ask about this refund'), findsNothing);
      },
    );
  }
}

class _PendingRefundRepository implements BookingRefundRepository {
  final result = Completer<BookingRefundProgress>();
  @override
  Future<BookingRefundProgress> getProgress(String bookingId) => result.future;
}

class _SessionStorage implements SecureStorageService {
  _SessionStorage(this.role);
  final UserRole role;
  @override
  Future<String?> read(String key) async => switch (key) {
    AppConstants.accessTokenKey => 'test-access',
    AppConstants.refreshTokenKey => 'test-refresh',
    AppConstants.keepSignedInKey => 'true',
    AppConstants.sessionRoleKey =>
      role == UserRole.traveler ? 'traveler' : 'tourOperator',
    AppConstants.sessionApplicationStatusKey => 'Approved',
    _ => null,
  };
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<void> write(String key, String value) async {}
}

class _RefundRepository implements BookingRefundRepository {
  @override
  Future<BookingRefundProgress> getProgress(String bookingId) async =>
      BookingRefundProgress(
        bookingId: 42,
        bookingCode: 'TM42',
        refundAmount: 100,
        status: BookingRefundStatus.processing,
        attemptCount: 1,
        requestedAtUtc: DateTime.utc(2026),
      );
}
