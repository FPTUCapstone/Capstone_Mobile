import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_cubit.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_state.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';

import 'partial_refund_proposal_fakes.dart';

void main() {
  late FakePartialRefundProposalRepository repository;
  late PartialRefundProposalCubit cubit;

  setUp(() {
    repository = FakePartialRefundProposalRepository();
    cubit = buildCubit(repository);
  });

  tearDown(() => cubit.close());

  test('loads the proposal of the complaint', () async {
    repository.reads.add(openProposal());

    await cubit.load();

    expect(repository.calls, ['get:501']);
    expect(cubit.state.loadStatus, PartialRefundProposalLoadStatus.loaded);
    expect(cubit.state.proposal, openProposal());
  });

  test('shows MSG126 when the booking belongs to another traveler', () async {
    repository.reads.add(const PermissionFailure('server text'));

    await cubit.load();

    expect(cubit.state.loadStatus, PartialRefundProposalLoadStatus.failure);
    expect(cubit.state.message, PartialRefundProposalStrings.accessDenied);
    expect(cubit.state.canRetry, isFalse);
  });

  test('shows MSG127 with a retry when loading fails', () async {
    repository.reads.add(const NetworkFailure());

    await cubit.load();

    expect(cubit.state.message, PartialRefundProposalStrings.systemError);
    expect(cubit.state.canRetry, isTrue);
  });

  for (final decision in PartialRefundDecision.values) {
    test('records ${decision.wireValue} and closes the proposal', () async {
      repository
        ..reads.add(openProposal())
        ..responses.add(recorded(decision));
      await cubit.load();

      await cubit.respond(decision);

      expect(repository.calls.last, 'respond:501:${decision.wireValue}');
      expect(cubit.state.submitStatus, PartialRefundSubmitStatus.recorded);
      expect(cubit.state.answeredHere, isTrue);
      expect(cubit.state.proposal!.canRespond, isFalse);
      expect(
        cubit.state.proposal!.status,
        decision == PartialRefundDecision.accept
            ? PartialRefundProposalStatus.approved
            : PartialRefundProposalStatus.declined,
      );
    });
  }

  test('a closed window reloads the proposal and makes no change', () async {
    repository
      ..reads.add(openProposal())
      ..responses.add(
        const ConflictFailure(PartialRefundProposalStrings.responseClosed),
      )
      ..reads.add(
        openProposal(
          status: PartialRefundProposalStatus.declined,
          canRespond: false,
        ),
      );
    await cubit.load();

    await cubit.respond(PartialRefundDecision.accept);

    expect(repository.calls, ['get:501', 'respond:501:Accept', 'get:501']);
    expect(cubit.state.submitStatus, PartialRefundSubmitStatus.closed);
    expect(cubit.state.answeredHere, isFalse);
    expect(cubit.state.proposal!.status, PartialRefundProposalStatus.declined);
    expect(cubit.state.proposal!.canRespond, isFalse);
  });

  test(
    'a closed window still hides the buttons when the reload fails',
    () async {
      repository
        ..reads.add(openProposal())
        ..responses.add(
          const ConflictFailure(PartialRefundProposalStrings.responseClosed),
        )
        ..reads.add(const NetworkFailure());
      await cubit.load();

      await cubit.respond(PartialRefundDecision.decline);

      expect(cubit.state.submitStatus, PartialRefundSubmitStatus.closed);
      expect(
        cubit.state.proposal!.status,
        PartialRefundProposalStatus.awaitingTravelerResponse,
      );
      expect(cubit.state.proposal!.canRespond, isFalse);
    },
  );

  test('a failed send shows MSG127 and keeps the proposal open', () async {
    repository
      ..reads.add(openProposal())
      ..responses.add(const ServerFailure());
    await cubit.load();

    await cubit.respond(PartialRefundDecision.accept);

    expect(cubit.state.submitStatus, PartialRefundSubmitStatus.failed);
    expect(cubit.state.message, PartialRefundProposalStrings.systemError);
    expect(cubit.state.proposal, openProposal());
  });

  test('ignores a second answer while the first one is being sent', () async {
    final hold = Completer<void>();
    repository
      ..reads.add(openProposal())
      ..responses.add(recorded(PartialRefundDecision.accept))
      ..holdResponse = hold;
    await cubit.load();

    final first = cubit.respond(PartialRefundDecision.accept);
    await cubit.respond(PartialRefundDecision.decline);
    hold.complete();
    await first;

    expect(repository.calls.where((call) => call.startsWith('respond')), [
      'respond:501:Accept',
    ]);
  });

  test(
    'does not send an answer when the proposal cannot be answered',
    () async {
      repository.reads.add(openProposal(canRespond: false));
      await cubit.load();

      await cubit.respond(PartialRefundDecision.accept);

      expect(repository.calls, ['get:501']);
    },
  );
}
