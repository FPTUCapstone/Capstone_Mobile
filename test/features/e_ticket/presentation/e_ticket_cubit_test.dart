import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/repositories/e_ticket_repository.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/get_e_ticket_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/refresh_e_ticket_qr_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_cubit.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_state.dart';

ETicket eTicket({
  ETicketStatus status = ETicketStatus.valid,
  String? qrContent = 'TM1.first.sig',
  DateTime? checkedInAtUtc,
}) => ETicket(
  ticketId: 77,
  ticketCode: 'TK-0000000456',
  bookingId: 456,
  bookingCode: 'BK-20261017-00001',
  status: status,
  tourId: 45,
  tourTitle: 'Hoi An Lantern Tour',
  operatorName: 'Hoi An Travel Co.',
  startAtUtc: DateTime.utc(2026, 10, 30, 1),
  endAtUtc: DateTime.utc(2026, 10, 30, 10),
  meetingPoint: 'Old Town gate',
  participantCount: 3,
  adults: 2,
  children: 1,
  infants: 0,
  departureDate: DateTime.utc(2026, 10, 30),
  validFromUtc: DateTime.utc(2026, 10, 29, 17),
  validUntilUtc: DateTime.utc(2026, 10, 30, 16, 59, 59),
  checkedInAtUtc: checkedInAtUtc,
  qr: qrContent == null
      ? null
      : ETicketQr(
          content: qrContent,
          issuedAtUtc: DateTime.utc(2026, 10, 24, 8, 15),
        ),
);

final class FakeETicketRepository implements ETicketRepository {
  final List<String> calls = [];
  final List<Object> reads = [];
  final List<Object> refreshes = [];

  Future<ETicket> _next(List<Object> queue) async {
    final next = queue.removeAt(0);
    if (next is ETicketFailure) throw next;
    return next as ETicket;
  }

  @override
  Future<ETicket> getTicket(int ticketId) {
    calls.add('ticket:$ticketId');
    return _next(reads);
  }

  @override
  Future<ETicket> getBookingTicket(int bookingId) {
    calls.add('booking:$bookingId');
    return _next(reads);
  }

  @override
  Future<ETicket> refreshQr(int ticketId) {
    calls.add('refresh:$ticketId');
    return _next(refreshes);
  }
}

final class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});

  bool connected;

  /// When set, the connectivity check fails like a missing platform plugin.
  bool failCheck = false;
  final StreamController<bool> changes = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async {
    if (failCheck) throw StateError('connectivity unavailable');
    return connected;
  }

  @override
  Stream<bool> get onConnectivityChanged => changes.stream;
}

ETicketCubit buildCubit(
  FakeETicketRepository repository,
  FakeNetworkInfo network, {
  ETicketKey key = const ETicketKey.ticket(77),
}) => ETicketCubit(
  key: key,
  getTicket: GetETicketUseCase(repository),
  refreshQr: RefreshETicketQrUseCase(repository),
  networkInfo: network,
);

void main() {
  late FakeETicketRepository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = FakeETicketRepository();
    network = FakeNetworkInfo();
  });

  test('loads the ticket and is ready to refresh when online', () async {
    repository.reads.add(eTicket());
    final cubit = buildCubit(repository, network);

    await cubit.start();

    expect(cubit.state.phase, ETicketPhase.ready);
    expect(cubit.state.ticket, eTicket());
    expect(cubit.state.online, isTrue);
    expect(cubit.state.canRefresh, isTrue);
    await cubit.close();
  });

  test('opens the ticket of a booking by booking id', () async {
    repository.reads.add(eTicket());
    final cubit = buildCubit(
      repository,
      network,
      key: const ETicketKey.booking(456),
    );

    await cubit.start();

    expect(repository.calls, ['booking:456']);
    await cubit.close();
  });

  for (final kind in ETicketFailureKind.values) {
    test('shows the $kind failure', () async {
      repository.reads.add(ETicketFailure(kind));
      final cubit = buildCubit(repository, network);

      await cubit.start();

      expect(cubit.state.phase, ETicketPhase.failure);
      expect(cubit.state.failure, kind);
      expect(cubit.state.ticket, isNull);
      await cubit.close();
    });
  }

  test('retry reads the ticket again', () async {
    repository.reads
      ..add(const ETicketFailure(ETicketFailureKind.system))
      ..add(eTicket());
    final cubit = buildCubit(repository, network);
    await cubit.start();

    await cubit.load();

    expect(cubit.state.phase, ETicketPhase.ready);
  });

  test('refresh replaces the QR', () async {
    repository.reads.add(eTicket());
    repository.refreshes.add(eTicket(qrContent: 'TM1.second.sig'));
    final cubit = buildCubit(repository, network);
    await cubit.start();

    await cubit.refresh();

    expect(cubit.state.ticket?.qr?.content, 'TM1.second.sig');
    expect(cubit.state.refreshing, isFalse);
    expect(cubit.state.staleQr, isFalse);
    expect(repository.calls, ['ticket:77', 'refresh:77']);
    await cubit.close();
  });

  test(
    're-reads by ticket id when the ticket can no longer be refreshed',
    () async {
      repository.reads
        ..add(eTicket())
        ..add(eTicket(status: ETicketStatus.used, qrContent: null));
      repository.refreshes.add(
        const ETicketFailure(
          ETicketFailureKind.notRefreshable,
          ticketStatus: ETicketStatus.used,
        ),
      );
      final cubit = buildCubit(
        repository,
        network,
        key: const ETicketKey.booking(456),
      );
      await cubit.start();

      await cubit.refresh();

      expect(cubit.state.ticket?.status, ETicketStatus.used);
      expect(cubit.state.ticket?.qr, isNull);
      expect(cubit.state.canRefresh, isFalse);
      expect(repository.calls, ['booking:456', 'refresh:77', 'ticket:77']);
      await cubit.close();
    },
  );

  test(
    'shows the re-read QR when a refresh fails but the re-read works',
    () async {
      repository.reads
        ..add(eTicket())
        ..add(eTicket(qrContent: 'TM1.server.sig'));
      repository.refreshes.add(const ETicketFailure(ETicketFailureKind.system));
      final cubit = buildCubit(repository, network);
      await cubit.start();

      await cubit.refresh();

      expect(cubit.state.ticket?.qr?.content, 'TM1.server.sig');
      expect(cubit.state.staleQr, isFalse);
      await cubit.close();
    },
  );

  test(
    'keeps the last ticket with a stale warning when both calls fail',
    () async {
      repository.reads
        ..add(eTicket())
        ..add(const ETicketFailure(ETicketFailureKind.system));
      repository.refreshes.add(const ETicketFailure(ETicketFailureKind.system));
      final cubit = buildCubit(repository, network);
      await cubit.start();

      await cubit.refresh();

      expect(cubit.state.phase, ETicketPhase.ready);
      expect(cubit.state.ticket?.qr?.content, 'TM1.first.sig');
      expect(cubit.state.staleQr, isTrue);
      await cubit.close();
    },
  );

  test(
    'connectivity changes toggle refreshing, and offline refresh does nothing',
    () async {
      repository.reads.add(eTicket());
      final cubit = buildCubit(repository, network);
      await cubit.start();

      network.changes.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.online, isFalse);
      expect(cubit.state.canRefresh, isFalse);
      await cubit.refresh();
      expect(repository.calls, ['ticket:77']);

      network.changes.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.canRefresh, isTrue);
      await cubit.close();
    },
  );

  test('starts offline when the device has no connection', () async {
    network.connected = false;
    repository.reads.add(eTicket());
    final cubit = buildCubit(repository, network);

    await cubit.start();

    expect(cubit.state.online, isFalse);
    expect(cubit.state.ticket, isNotNull);
    await cubit.close();
  });

  test('still loads the ticket when the connectivity check fails', () async {
    network.failCheck = true;
    repository.reads.add(eTicket());
    final cubit = buildCubit(repository, network);

    await cubit.start();

    expect(cubit.state.phase, ETicketPhase.ready);
    expect(cubit.state.online, isTrue);
    await cubit.close();
  });

  test('a used ticket cannot be refreshed', () async {
    repository.reads.add(eTicket(status: ETicketStatus.used, qrContent: null));
    final cubit = buildCubit(repository, network);
    await cubit.start();

    await cubit.refresh();

    expect(cubit.state.canRefresh, isFalse);
    expect(repository.calls, ['ticket:77']);
    await cubit.close();
  });
}
