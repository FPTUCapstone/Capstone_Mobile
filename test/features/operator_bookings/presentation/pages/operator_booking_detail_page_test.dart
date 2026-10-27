import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/pages/operator_booking_detail_page.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';

import '../../operator_bookings_fixtures.dart';

final class _FakeRepository implements OperatorBookingsRepository {
  final List<String> requested = [];
  Future<OperatorBookingDetail> Function(String id)? onDetail;

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) {
    requested.add(bookingId);
    final handler = onDetail;
    return handler == null
        ? Future.value(OperatorBookingsJson.detail(detailJson(id: bookingId)))
        : handler(bookingId);
  }

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() =>
      throw UnimplementedError();
}

OperatorBookingListItem _summary() => OperatorBookingsJson.page(
  listPageJson(items: [listBookingJson()]),
).items.single;

OperatorBookingDetail _detail(void Function(Map<String, Object?> body) tweak) {
  final body = detailJson();
  tweak(body);
  return OperatorBookingsJson.detail(body);
}

void main() {
  late _FakeRepository repository;
  late OperatorBookingDetailCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = OperatorBookingDetailCubit(
      getBooking: GetOperatorBookingUseCase(repository),
      bookingId: '1201',
    );
  });

  tearDown(() => cubit.close());

  void useSize(WidgetTester tester, Size size, {double textScale = 1}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pump(
    WidgetTester tester, {
    OperatorBookingListItem? initial,
    bool load = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<OperatorBookingDetailCubit>.value(
          value: cubit,
          child: OperatorBookingDetailPage(initialBooking: initial),
        ),
      ),
    );
    if (load) {
      await cubit.load();
      await tester.pump();
    }
  }

  testWidgets(
    'shows the list-card basics at once with a placeholder, then the detail',
    (tester) async {
      final gate = Completer<OperatorBookingDetail>();
      repository.onDetail = (_) => gate.future;
      await pump(tester, initial: _summary(), load: false);
      unawaited(cubit.load());
      await tester.pump();

      expect(find.text(OperatorBookingsStringsEn.detailTitle), findsOneWidget);
      expect(find.text('BK-20261020-0007'), findsOneWidget);
      expect(find.text('Ba Na Hills full-day tour'), findsOneWidget);
      expect(
        find.byKey(const Key('operator-booking-detail-loading')),
        findsOneWidget,
      );
      expect(find.text(OperatorBookingsStringsEn.detailManifest), findsNothing);

      gate.complete(OperatorBookingsJson.detail(detailJson()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('operator-booking-detail-loading')),
        findsNothing,
      );
      expect(
        find.text(OperatorBookingsStringsEn.detailManifest),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a progress indicator when opened without any basics', (
    tester,
  ) async {
    final gate = Completer<OperatorBookingDetail>();
    repository.onDetail = (_) => gate.future;
    await pump(tester, load: false);
    unawaited(cubit.load());
    await tester.pump();

    expect(
      find.byKey(const Key('operator-booking-detail-loading')),
      findsOneWidget,
    );
    expect(find.text(OperatorBookingsStringsEn.detailTitle), findsOneWidget);
  });

  testWidgets(
    'shows the tour, schedule, check-in, booker and the passenger manifest',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Da Nang Cruise Port'), findsOneWidget);
      expect(find.textContaining('02/11/2026'), findsWidgets);
      expect(find.text('+84901234567'), findsOneWidget);
      expect(find.text('a@example.com'), findsOneWidget);
      expect(find.text('Nguyen Thi B'), findsOneWidget);
      expect(
        find.text(OperatorBookingsStringsEn.participantChild),
        findsOneWidget,
      );
      expect(
        find.text(OperatorBookingsStringsEn.participantAdult),
        findsOneWidget,
      );
      expect(find.textContaining('(2)'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the e-ticket, the read-only payment and the pricing with the coupon',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('TK-0000001201'), findsOneWidget);
      expect(find.text('PayOS'), findsOneWidget);
      expect(find.text('FT26102012345'), findsOneWidget);
      expect(find.text('2,500,000 VND'), findsOneWidget); // subtotal
      expect(find.textContaining('SUMMER10'), findsOneWidget);
      expect(find.text('100,000 VND'), findsWidgets); // discount
      expect(find.text('2,400,000 VND'), findsWidgets); // total / paid
    },
  );

  testWidgets('shows the check-in time when the booking was checked in', (
    tester,
  ) async {
    repository.onDetail = (_) async => _detail(
      (body) => body
        ..['checkInStatus'] = 'CheckedIn'
        ..['checkedInAtUtc'] = '2026-11-02T01:30:00+00:00',
    );
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('02/11/2026 08:30'), findsOneWidget);
  });

  testWidgets(
    'hides the ticket, payment, coupon and meeting point when the BE returns null for them',
    (tester) async {
      repository.onDetail = (_) async => _detail((body) {
        body
          ..['ticket'] = null
          ..['payment'] = null
          ..['coupon'] = null
          ..['paidAmount'] = 0;
        (body['schedule']! as Map<String, Object?>)['meetingPoint'] = null;
      });
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text(OperatorBookingsStringsEn.detailTicket), findsNothing);
      expect(find.text(OperatorBookingsStringsEn.detailPayment), findsNothing);
      expect(find.text(OperatorBookingsStringsEn.detailCoupon), findsNothing);
      expect(
        find.text(OperatorBookingsStringsEn.detailMeetingPoint),
        findsNothing,
      );
      expect(find.text('0 VND'), findsOneWidget); // paid amount stays honest
      expect(
        find.text(OperatorBookingsStringsEn.detailManifest),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows the cancellation record for a cancelled booking', (
    tester,
  ) async {
    repository.onDetail = (_) async => _detail(
      (body) => body
        ..['status'] = 'Cancelled'
        ..['cancelledAtUtc'] = '2026-10-25T01:00:00+00:00'
        ..['cancelReason'] = 'Operator: heavy weather'
        ..['canCancel'] = false
        ..['cancelBlockedReason'] = 'InvalidStatus',
    );
    await pump(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(OperatorBookingsStringsEn.detailCancellation),
      findsOneWidget,
    );
    expect(find.text('Operator: heavy weather'), findsOneWidget);
    expect(find.textContaining('25/10/2026'), findsOneWidget);
  });

  testWidgets(
    'a generic failure shows the system text with Retry, keeps the basics, and Retry reloads',
    (tester) async {
      var attempt = 0;
      repository.onDetail = (id) => ++attempt == 1
          ? Future.error(const NetworkFailure())
          : Future.value(OperatorBookingsJson.detail(detailJson(id: id)));
      await pump(tester, initial: _summary());

      expect(find.text(OperatorBookingsStringsEn.systemError), findsOneWidget);
      expect(find.text('BK-20261020-0007'), findsOneWidget);
      expect(find.text(OperatorBookingsStringsEn.detailManifest), findsNothing);

      await tester.tap(find.text(OperatorBookingsStringsEn.retry));
      await tester.pumpAndSettle();

      expect(repository.requested, ['1201', '1201']);
      expect(find.text(OperatorBookingsStringsEn.systemError), findsNothing);
      expect(
        find.text(OperatorBookingsStringsEn.detailManifest),
        findsOneWidget,
      );
    },
  );

  testWidgets('an access failure shows the permission text and no Retry', (
    tester,
  ) async {
    repository.onDetail = (_) => Future.error(const NotFoundFailure());
    await pump(tester);

    expect(find.text(OperatorBookingsStringsEn.accessDenied), findsOneWidget);
    expect(find.text(OperatorBookingsStringsEn.retry), findsNothing);
  });

  testWidgets(
    'shows no cancel, refund or check-in control and no participant contact data',
    (tester) async {
      final body = detailJson();
      ((body['participants']! as List<Object?>).first! as Map<String, Object?>)
        ..['phoneNumber'] = '+84900000001'
        ..['email'] = 'a@secret.example'
        ..['idDocumentNumber'] = 'P1234567'
        ..['nationality'] = 'VNM'
        ..['age'] = 41;
      repository.onDetail = (_) async => OperatorBookingsJson.detail(body);
      await pump(tester);
      await tester.pumpAndSettle();

      for (final forbidden in [
        'check-in qr',
        'cancel booking',
        'refund',
        'pickup',
        'scan',
      ]) {
        expect(
          find.textContaining(RegExp(forbidden, caseSensitive: false)),
          findsNothing,
          reason: forbidden,
        );
      }
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      for (final secret in [
        '+84900000001',
        'a@secret.example',
        'P1234567',
        'VNM',
        '41',
      ]) {
        expect(find.textContaining(secret), findsNothing, reason: secret);
      }
    },
  );

  testWidgets(
    'fits a 320 dp wide screen at a large text scale without overflow',
    (tester) async {
      useSize(tester, const Size(320, 640), textScale: 2);
      repository.onDetail = (_) async => _detail(
        (body) => body['participants'] = [
          for (var i = 0; i < 6; i++)
            {
              'fullName': 'Nguyen Thi Thanh Huong Phuong Lan $i',
              'participantType': 'Adult',
            },
        ],
      );
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Nguyen Thi Thanh Huong Phuong Lan 5'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tester.takeException(), isNull);
    },
  );
}
