import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/repositories/traveler_emergency_repository.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_notices_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/widgets/traveler_emergency_banner.dart';

import '../../operator_weather_safety/support/fake_operator_weather_safety_repository.dart'
    show FakeNetworkInfo;

TravelerEmergencyNotice notice(
  int bookingId, {
  bool acknowledged = false,
  EmergencyAction action = EmergencyAction.cancelBeforeDeparture,
}) => TravelerEmergencyNotice(
  bookingId: bookingId,
  scheduleId: bookingId + 100,
  action: action,
  committedAtUtc: DateTime.utc(2026, 11, 3),
  acknowledgedAtUtc: acknowledged ? DateTime.utc(2026, 11, 3, 1) : null,
);

void main() {
  late _Repository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = _Repository();
    network = FakeNetworkInfo();
  });

  TravelerEmergencyNoticesCubit create() => TravelerEmergencyNoticesCubit(
    getNotices: GetTravelerEmergencyNoticesUseCase(repository),
    networkInfo: network,
  );

  group('cubit', () {
    test('discovers a notice without any push', () async {
      repository.notices = [notice(42)];
      final cubit = create();

      await cubit.refresh();

      expect(cubit.state.notices.single.bookingId, 42);
      expect(cubit.state.unread, hasLength(1));
      expect(cubit.state.hasNoticeFor(42), isTrue);
      expect(cubit.state.hasNoticeFor(43), isFalse);
      await cubit.close();
    });

    test(
      'an acknowledged notice stays listed but is no longer unread',
      () async {
        repository.notices = [notice(42, acknowledged: true)];
        final cubit = create();

        await cubit.refresh();

        expect(cubit.state.hasNoticeFor(42), isTrue);
        expect(cubit.state.unread, isEmpty);
        await cubit.close();
      },
    );

    test('a failed refresh keeps what is known', () async {
      repository.notices = [notice(42)];
      final cubit = create();
      await cubit.refresh();
      repository.failure = const ServerFailure();

      await cubit.refresh();

      expect(cubit.state.notices, hasLength(1));
      await cubit.close();
    });

    test('offline makes no request', () async {
      network.connected = false;
      final cubit = create();

      await cubit.refresh();

      expect(repository.calls, 0);
      await cubit.close();
    });

    test('reconnecting recovers a missed notice', () async {
      final cubit = create();
      await cubit.refresh();
      repository.notices = [notice(42)];

      network.change(true);
      await pumpEventQueue();

      expect(cubit.state.unread, hasLength(1));
      await cubit.close();
    });

    test('reset forgets the previous account', () async {
      repository.notices = [notice(42)];
      final cubit = create();
      await cubit.refresh();

      cubit.reset();

      expect(cubit.state.notices, isEmpty);
      await cubit.close();
    });
  });

  group('banner', () {
    Future<void> pump(
      WidgetTester tester,
      List<TravelerEmergencyNotice> unread,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TravelerEmergencyBanner(unread: unread, onOpen: _opened.add),
        ),
      ),
    );

    setUp(_opened.clear);

    testWidgets('nothing unread shows nothing', (tester) async {
      await pump(tester, const []);

      expect(find.byKey(const Key('emergency-banner')), findsNothing);
    });

    testWidgets('one notice opens that booking', (tester) async {
      await pump(tester, [notice(42, action: EmergencyAction.emergencyStop)]);

      await tester.tap(find.byKey(const Key('emergency-banner')));

      expect(_opened.single, 42);
      expect(find.textContaining('stopped for safety'), findsOneWidget);
    });

    testWidgets('several notices open the list', (tester) async {
      await pump(tester, [notice(42), notice(43)]);

      await tester.tap(find.byKey(const Key('emergency-banner')));

      expect(_opened.single, isNull);
      expect(find.textContaining('2'), findsOneWidget);
    });
  });
}

final _opened = <int?>[];

final class _Repository implements TravelerEmergencyRepository {
  List<TravelerEmergencyNotice> notices = [];
  Object? failure;
  int calls = 0;

  @override
  Future<List<TravelerEmergencyNotice>> getNotices() async {
    calls++;
    final current = failure;
    if (current != null) throw current;
    return notices;
  }

  @override
  Future<TravelerEmergencyStatus> getStatus(int bookingId) =>
      throw UnimplementedError();

  @override
  Future<DateTime> acknowledge(int bookingId) => throw UnimplementedError();
}
