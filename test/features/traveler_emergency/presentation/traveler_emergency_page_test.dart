import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/repositories/traveler_emergency_repository.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/pages/traveler_emergency_page.dart';

import '../../operator_weather_safety/support/fake_operator_weather_safety_repository.dart'
    show FakeNetworkInfo;
import '../support/traveler_emergency_fixtures.dart';

void main() {
  late _FakeRepository repository;
  late FakeNetworkInfo network;
  late List<Uri> dialled;

  setUp(() {
    repository = _FakeRepository();
    network = FakeNetworkInfo();
    dialled = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    Size size = const Size(400, 800),
    bool dialSucceeds = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = TravelerEmergencyCubit(
      bookingId: 42,
      getStatus: GetTravelerEmergencyStatusUseCase(repository),
      acknowledge: AcknowledgeTravelerEmergencyStatusUseCase(repository),
      networkInfo: network,
    );
    addTearDown(cubit.close);
    unawaited(cubit.load());
    // The real route patterns, with placeholders for the destinations, so a
    // tap proves which existing screen the page opens.
    final router = GoRouter(
      initialLocation: AppRoutes.travelerEmergency(42),
      routes: [
        GoRoute(
          path: AppRoutes.travelerEmergencyPattern,
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: TravelerEmergencyPage(
              dial: (uri) async {
                dialled.add(uri);
                return dialSucceeds;
              },
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.bookingRefundPattern,
          builder: (_, state) => Scaffold(
            body: Text('Refund progress ${state.pathParameters['bookingId']}'),
          ),
        ),
        GoRoute(
          path: AppRoutes.tourDetailPattern,
          builder: (_, state) =>
              Scaffold(body: Text('Tour ${state.pathParameters['tourId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const refundSubmittedCopy =
      'Bạn sẽ được hoàn 100% số tiền đã thanh toán. Yêu cầu hoàn tiền đã được tạo.';
  const underReviewStopCopy =
      'Tour đã dừng vì lý do an toàn. Phần dịch vụ chưa thực hiện sẽ được '
      'TripMate xem xét hoàn tiền. Kết quả sẽ được thông báo cho bạn.';
  const underReviewCancelCopy =
      'Khoản thanh toán của bạn đang được TripMate kiểm tra để hoàn tiền. '
      'Kết quả sẽ được thông báo cho bạn.';
  const notApplicableCopy =
      'Booking này chưa được thanh toán nên không phát sinh hoàn tiền.';
  const unknownCopy =
      'TripMate sẽ thông báo cho bạn về việc hoàn tiền (nếu có).';
  const oldCopy =
      'Việc thanh toán và hoàn tiền được xử lý riêng theo chính sách hủy booking áp dụng.';
  final refundButton = find.byKey(const Key('emergency-refund-progress'));
  final rebookButton = find.byKey(const Key('emergency-rebook'));

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  testWidgets('an emergency stop leads with safety before commercial detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2000);
    await pump(tester, size: const Size(400, 2000));

    final instructions = top(tester, find.text('Stay at the shelter.'));
    final contact = top(tester, find.textContaining('Hotline'));
    final booking = top(tester, find.text('Đơn đặt tour của bạn'));
    final notice = top(tester, find.text(unknownCopy));
    final acknowledge = top(tester, find.byKey(const Key('emergency-ack')));

    expect(instructions, lessThan(contact));
    expect(contact, lessThan(booking));
    expect(booking, lessThan(notice));
    expect(notice, lessThan(acknowledge));
  });

  testWidgets('a cancellation shows reason and schedule state', (tester) async {
    repository.status = TravelerEmergencyFixture.build(
      action: EmergencyAction.cancelBeforeDeparture,
      immediateInstructions: null,
    );

    await pump(tester);

    expect(find.text('Tour đã bị hủy'), findsOneWidget);
    expect(find.text('Road closed'), findsOneWidget);
    expect(find.text('Chỉ dẫn khẩn cấp'), findsNothing);
  });

  group('refund handling copy', () {
    final cases = [
      (
        RefundHandling.refundSubmitted,
        EmergencyAction.cancelBeforeDeparture,
        refundSubmittedCopy,
      ),
      (
        RefundHandling.underReview,
        EmergencyAction.emergencyStop,
        underReviewStopCopy,
      ),
      (
        RefundHandling.underReview,
        EmergencyAction.cancelBeforeDeparture,
        underReviewCancelCopy,
      ),
      (
        RefundHandling.notApplicable,
        EmergencyAction.cancelBeforeDeparture,
        notApplicableCopy,
      ),
      (
        RefundHandling.notApplicable,
        EmergencyAction.emergencyStop,
        notApplicableCopy,
      ),
      (RefundHandling.unknown, EmergencyAction.emergencyStop, unknownCopy),
      (
        RefundHandling.unknown,
        EmergencyAction.cancelBeforeDeparture,
        unknownCopy,
      ),
      (RefundHandling.underReview, EmergencyAction.unknown, unknownCopy),
    ];
    for (final (handling, action, copy) in cases) {
      testWidgets('$handling + $action shows its own line', (tester) async {
        repository.status = TravelerEmergencyFixture.build(
          action: action,
          refundHandling: handling,
        );

        await pump(tester);

        expect(find.text(copy), findsOneWidget);
        expect(find.text(oldCopy), findsNothing);
        expect(find.textContaining('VND'), findsNothing);
      });
    }
  });

  group('refund progress button', () {
    testWidgets('opens the refund progress of this booking', (tester) async {
      repository.status = TravelerEmergencyFixture.build(
        action: EmergencyAction.cancelBeforeDeparture,
        refundHandling: RefundHandling.refundSubmitted,
      );
      await pump(tester);

      expect(find.text('Xem tiến độ hoàn tiền'), findsOneWidget);
      await tapVisible(tester, refundButton);

      expect(find.text('Refund progress 42'), findsOneWidget);
    });

    for (final handling in [
      RefundHandling.underReview,
      RefundHandling.notApplicable,
      RefundHandling.unknown,
    ]) {
      testWidgets('is hidden when refund handling is $handling', (
        tester,
      ) async {
        repository.status = TravelerEmergencyFixture.build(
          action: EmergencyAction.cancelBeforeDeparture,
          refundHandling: handling,
        );

        await pump(tester);

        expect(refundButton, findsNothing);
      });
    }
  });

  group('rebooking button', () {
    testWidgets('a cancelled departure opens the same tour to book again', (
      tester,
    ) async {
      repository.status = TravelerEmergencyFixture.build(
        action: EmergencyAction.cancelBeforeDeparture,
        refundHandling: RefundHandling.refundSubmitted,
        tourId: 12,
      );
      await pump(tester);

      expect(find.text('Đặt chuyến khác'), findsOneWidget);
      await tapVisible(tester, rebookButton);

      expect(find.text('Tour 12'), findsOneWidget);
    });

    testWidgets('an emergency stop offers no rebooking', (tester) async {
      repository.status = TravelerEmergencyFixture.build(tourId: 12);

      await pump(tester);

      expect(rebookButton, findsNothing);
    });

    testWidgets('an older Backend without the tour id offers no rebooking', (
      tester,
    ) async {
      repository.status = TravelerEmergencyFixture.build(
        action: EmergencyAction.cancelBeforeDeparture,
      );

      await pump(tester);

      expect(rebookButton, findsNothing);
    });
  });

  testWidgets('the Call action dials the published number', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('emergency-call')));
    await tester.pumpAndSettle();

    expect(dialled.single, Uri(scheme: 'tel', path: '+84900000000'));
  });

  testWidgets('a device that cannot dial still shows the contact', (
    tester,
  ) async {
    await pump(tester, dialSucceeds: false);

    await tester.tap(find.byKey(const Key('emergency-call')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không thể gọi'), findsOneWidget);
    expect(find.textContaining('Hotline'), findsOneWidget);
  });

  testWidgets('a contact without a number has no Call action', (tester) async {
    repository.status = TravelerEmergencyFixture.build(
      emergencyContact: 'Ask your tour guide',
    );

    await pump(tester);

    expect(find.byKey(const Key('emergency-call')), findsNothing);
    expect(find.text('Ask your tour guide'), findsOneWidget);
  });

  testWidgets('acknowledging keeps the record and explains what it means', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('không có nghĩa là'), findsOneWidget);

    final button = find.byKey(const Key('emergency-ack'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.acknowledgeCalls, 1);
    expect(find.byKey(const Key('emergency-ack')), findsNothing);
    expect(find.textContaining('Đã ghi nhận lúc'), findsOneWidget);
    expect(find.text('Stay at the shelter.'), findsOneWidget);
  });

  testWidgets('the owner is reminded to tell unlinked companions', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('người đi cùng'), findsOneWidget);
  });

  testWidgets('a foreign booking is a Safe 404 that names nothing', (
    tester,
  ) async {
    repository.failure = const NotFoundFailure();

    await pump(tester);

    expect(find.text('Không có thông báo khẩn cấp'), findsOneWidget);
    expect(find.text('Stay at the shelter.'), findsNothing);
  });

  testWidgets('offline offers a retry and recovers', (tester) async {
    network.connected = false;
    await pump(tester);
    expect(find.text('Thử lại'), findsOneWidget);

    network.connected = true;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Stay at the shelter.'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps safety text and says it may be old', (
    tester,
  ) async {
    await pump(tester);
    repository.failure = const ServerFailure();

    await tester
        .state<State>(find.byType(TravelerEmergencyPage))
        .context
        .read<TravelerEmergencyCubit>()
        .load();
    await tester.pumpAndSettle();

    expect(find.text('Stay at the shelter.'), findsOneWidget);
    expect(find.textContaining('chưa được cập nhật'), findsOneWidget);
  });

  testWidgets('long text fits a small screen with large text', (tester) async {
    repository.status = TravelerEmergencyFixture.build(
      immediateInstructions: List.filled(80, 'Stay at the shelter.').join(' '),
    );

    await pump(tester, textScale: 2, size: const Size(320, 568));

    expect(tester.takeException(), isNull);
  });
}

final class _FakeRepository implements TravelerEmergencyRepository {
  TravelerEmergencyStatus status = TravelerEmergencyFixture.build();
  Object? failure;
  int acknowledgeCalls = 0;

  @override
  Future<List<TravelerEmergencyNotice>> getNotices() async => const [];

  @override
  Future<TravelerEmergencyStatus> getStatus(int bookingId) async {
    final current = failure;
    if (current != null) throw current;
    return status;
  }

  @override
  Future<DateTime> acknowledge(int bookingId) async {
    acknowledgeCalls++;
    return DateTime.utc(2026, 11, 10, 4);
  }
}
