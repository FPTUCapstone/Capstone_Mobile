import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_cubit.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/pages/partial_refund_proposal_page.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';

import 'partial_refund_proposal_fakes.dart';

void main() {
  late FakePartialRefundProposalRepository repository;

  setUp(() => repository = FakePartialRefundProposalRepository());

  Future<PartialRefundProposalCubit> pumpPage(WidgetTester tester) async {
    final cubit = buildCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const PartialRefundProposalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('shows the proposed amount and the deadline in Vietnam time', (
    tester,
  ) async {
    repository.reads.add(openProposal());

    await pumpPage(tester);

    expect(find.text('BK-UC75'), findsOneWidget);
    expect(find.text('500,000 VND'), findsOneWidget);
    // 03:00 UTC is 10:00 in Asia/Ho_Chi_Minh.
    expect(find.text('09/11/2026 10:00'), findsOneWidget);
    expect(find.text(PartialRefundProposalStrings.accept), findsOneWidget);
    expect(find.text(PartialRefundProposalStrings.decline), findsOneWidget);
  });

  testWidgets('accepting asks for confirmation, then shows MSG164', (
    tester,
  ) async {
    repository
      ..reads.add(openProposal())
      ..responses.add(recorded(PartialRefundDecision.accept));
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('partial_refund_accept')));
    await tester.pumpAndSettle();
    expect(find.text(PartialRefundProposalStrings.acceptTitle), findsOneWidget);
    expect(repository.calls, ['get:501']);

    await tester.tap(find.byKey(const Key('partial_refund_confirm')));
    await tester.pumpAndSettle();

    expect(repository.calls.last, 'respond:501:Accept');
    expect(find.text(PartialRefundProposalStrings.recorded), findsOneWidget);
    expect(
      find.text(PartialRefundProposalStrings.statusApproved.toUpperCase()),
      findsOneWidget,
    );
    expect(find.byKey(const Key('partial_refund_accept')), findsNothing);
    expect(
      find.text(PartialRefundProposalStrings.responseClosed),
      findsNothing,
    );
  });

  testWidgets('cancelling the confirmation sends nothing', (tester) async {
    repository.reads.add(openProposal());
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('partial_refund_decline')));
    await tester.pumpAndSettle();
    expect(
      find.text(PartialRefundProposalStrings.declineTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(PartialRefundProposalStrings.cancel));
    await tester.pumpAndSettle();

    expect(repository.calls, ['get:501']);
    expect(find.byKey(const Key('partial_refund_decline')), findsOneWidget);
  });

  testWidgets('a proposal that can no longer be answered shows MSG165', (
    tester,
  ) async {
    repository.reads.add(
      openProposal(
        status: PartialRefundProposalStatus.declined,
        canRespond: false,
      ),
    );

    await pumpPage(tester);

    expect(
      find.text(PartialRefundProposalStrings.responseClosed),
      findsOneWidget,
    );
    expect(
      find.text(PartialRefundProposalStrings.statusDeclined.toUpperCase()),
      findsOneWidget,
    );
    expect(find.byKey(const Key('partial_refund_accept')), findsNothing);
    expect(find.byKey(const Key('partial_refund_decline')), findsNothing);
  });

  testWidgets('a failed send shows MSG127 and keeps the buttons', (
    tester,
  ) async {
    repository
      ..reads.add(openProposal())
      ..responses.add(const NetworkFailure());
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('partial_refund_decline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('partial_refund_confirm')));
    await tester.pumpAndSettle();

    expect(find.text(PartialRefundProposalStrings.systemError), findsOneWidget);
    expect(find.byKey(const Key('partial_refund_decline')), findsOneWidget);
  });

  testWidgets('access to another traveler booking shows MSG126', (
    tester,
  ) async {
    repository.reads.add(const PermissionFailure());

    await pumpPage(tester);

    expect(
      find.text(PartialRefundProposalStrings.accessDenied),
      findsOneWidget,
    );
    expect(find.text(PartialRefundProposalStrings.retry), findsNothing);
  });
}
