import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_cubit.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/pages/e_ticket_page.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/widgets/e_ticket_qr_code.dart';
import 'package:trip_mate_mobile/features/e_ticket/resources/e_ticket_en.dart';

import 'e_ticket_cubit_test.dart'
    show FakeETicketRepository, FakeNetworkInfo, buildCubit, eTicket;

Future<ETicketCubit> pumpPage(
  WidgetTester tester,
  FakeETicketRepository repository,
  FakeNetworkInfo network, {
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = buildCubit(repository, network);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(value: cubit, child: const ETicketPage()),
    ),
  );
  await cubit.start();
  await tester.pumpAndSettle();
  return cubit;
}

String? qrData(WidgetTester tester) {
  final finder = find.byType(ETicketQrCode);
  if (finder.evaluate().isEmpty) return null;
  expect(find.byType(QrImageView), findsOneWidget);
  return tester.widget<ETicketQrCode>(finder).content;
}

Finder refreshButton() =>
    find.widgetWithText(FilledButton, ETicketStrings.refresh);

void main() {
  late FakeETicketRepository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = FakeETicketRepository();
    network = FakeNetworkInfo();
  });

  testWidgets('shows a valid ticket with exactly the server QR content', (
    tester,
  ) async {
    repository.reads.add(eTicket());

    await pumpPage(tester, repository, network);

    expect(qrData(tester), 'TM1.first.sig');
    expect(
      find.text(ETicketStrings.statusLabel(ETicketStatus.valid)),
      findsOneWidget,
    );
    expect(find.text(ETicketStrings.msg93), findsOneWidget);
    expect(find.text('Hoi An Lantern Tour'), findsOneWidget);
    expect(find.text('Hoi An Travel Co.'), findsOneWidget);
    expect(find.text('TK-0000000456'), findsWidgets);
    expect(find.text('BK-20261017-00001'), findsOneWidget);
    expect(find.text('30/10/2026 08:00'), findsOneWidget);
    expect(find.text('Old Town gate'), findsOneWidget);
    expect(find.text('2 adults, 1 child (3 travellers)'), findsOneWidget);
    expect(
      find.text(ETicketStrings.validityNote('30/10/2026')),
      findsOneWidget,
    );
    expect(refreshButton(), findsOneWidget);
  });

  final statuses = <ETicketStatus, (String, bool)>{
    ETicketStatus.notYetActive: (ETicketStrings.msg98('30/10/2026'), true),
    ETicketStatus.used: (ETicketStrings.msg95('30/10/2026 07:20'), false),
    ETicketStatus.cancelled: (
      ETicketStrings.msg139('BK-20261017-00001'),
      false,
    ),
    ETicketStatus.expired: (ETicketStrings.msg140('30/10/2026'), false),
  };
  for (final entry in statuses.entries) {
    testWidgets('shows ${entry.key} with its message and QR visibility', (
      tester,
    ) async {
      final (message, showsQr) = entry.value;
      repository.reads.add(
        eTicket(
          status: entry.key,
          qrContent: showsQr ? 'TM1.first.sig' : null,
          checkedInAtUtc: entry.key == ETicketStatus.used
              ? DateTime.utc(2026, 10, 30, 0, 20)
              : null,
        ),
      );

      await pumpPage(tester, repository, network);

      expect(find.text(message), findsOneWidget);
      expect(find.text(ETicketStrings.statusLabel(entry.key)), findsOneWidget);
      expect(qrData(tester) != null, showsQr);
      expect(refreshButton().evaluate().isNotEmpty, showsQr);
    });
  }

  testWidgets('refreshes only after confirmation', (tester) async {
    repository.reads.add(eTicket());
    repository.refreshes.add(eTicket(qrContent: 'TM1.second.sig'));
    await pumpPage(tester, repository, network);

    await tester.ensureVisible(refreshButton());
    await tester.tap(refreshButton());
    await tester.pumpAndSettle();
    expect(find.text(ETicketStrings.refreshConfirm), findsOneWidget);
    await tester.tap(find.text(ETicketStrings.cancel));
    await tester.pumpAndSettle();
    expect(repository.calls, ['ticket:77']);

    await tester.tap(refreshButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(ETicketStrings.confirmRefresh));
    await tester.pumpAndSettle();

    expect(repository.calls, ['ticket:77', 'refresh:77']);
    expect(qrData(tester), 'TM1.second.sig');
  });

  testWidgets('disables refresh and says why while offline', (tester) async {
    repository.reads.add(eTicket());
    network.connected = false;

    await pumpPage(tester, repository, network);

    expect(tester.widget<FilledButton>(refreshButton()).onPressed, isNull);
    expect(find.text(ETicketStrings.offline), findsOneWidget);
    expect(qrData(tester), 'TM1.first.sig');
  });

  testWidgets(
    'warns that the QR may be revoked when refresh and re-read fail',
    (tester) async {
      repository.reads
        ..add(eTicket())
        ..add(const ETicketFailure(ETicketFailureKind.system));
      repository.refreshes.add(const ETicketFailure(ETicketFailureKind.system));
      await pumpPage(tester, repository, network);

      await tester.ensureVisible(refreshButton());
      await tester.tap(refreshButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(ETicketStrings.confirmRefresh));
      await tester.pumpAndSettle();

      expect(find.text(ETicketStrings.staleQr), findsOneWidget);
      expect(find.text(ETicketStrings.msg127), findsOneWidget);
      expect(qrData(tester), 'TM1.first.sig');
    },
  );

  final failures = <ETicketFailureKind, String>{
    ETicketFailureKind.signIn: ETicketStrings.signIn,
    ETicketFailureKind.forbidden: ETicketStrings.msg126,
    ETicketFailureKind.notFound: ETicketStrings.notFound,
    ETicketFailureKind.notConfirmed: ETicketStrings.msg138,
    ETicketFailureKind.notIssued: ETicketStrings.msg127,
    ETicketFailureKind.system: ETicketStrings.msg127,
  };
  for (final entry in failures.entries) {
    testWidgets('shows the reviewed message for ${entry.key}', (tester) async {
      repository.reads.add(ETicketFailure(entry.key));

      await pumpPage(tester, repository, network);

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      final canRetry =
          entry.key == ETicketFailureKind.system ||
          entry.key == ETicketFailureKind.notIssued;
      expect(find.text(ETicketStrings.retry).evaluate().isNotEmpty, canRetry);
    });
  }

  testWidgets('retry reads the ticket again', (tester) async {
    repository.reads
      ..add(const ETicketFailure(ETicketFailureKind.system))
      ..add(eTicket());
    await pumpPage(tester, repository, network);

    await tester.tap(find.text(ETicketStrings.retry));
    await tester.pumpAndSettle();

    expect(qrData(tester), 'TM1.first.sig');
  });

  testWidgets('says when the meeting point is not set yet', (tester) async {
    final ticket = eTicket();
    repository.reads.add(
      ETicket(
        ticketId: ticket.ticketId,
        ticketCode: ticket.ticketCode,
        bookingId: ticket.bookingId,
        bookingCode: ticket.bookingCode,
        status: ticket.status,
        tourId: ticket.tourId,
        tourTitle: ticket.tourTitle,
        operatorName: ticket.operatorName,
        startAtUtc: ticket.startAtUtc,
        endAtUtc: ticket.endAtUtc,
        meetingPoint: null,
        participantCount: ticket.participantCount,
        adults: ticket.adults,
        children: ticket.children,
        infants: ticket.infants,
        departureDate: ticket.departureDate,
        validFromUtc: ticket.validFromUtc,
        validUntilUtc: ticket.validUntilUtc,
        checkedInAtUtc: null,
        qr: ticket.qr,
      ),
    );

    await pumpPage(tester, repository, network);

    expect(find.text(ETicketStrings.meetingPointMissing), findsOneWidget);
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    repository.reads.add(eTicket());

    await pumpPage(tester, repository, network, size: const Size(320, 568));

    expect(tester.takeException(), isNull);
    expect(qrData(tester), 'TM1.first.sig');
  });
}
