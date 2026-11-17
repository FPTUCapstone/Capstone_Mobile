import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/repositories/post_trip_complaint_repository.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/usecases/post_trip_complaint_use_cases.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/pages/post_trip_complaint_page.dart';

class _Repository implements PostTripComplaintRepository {
  @override
  Future<PostTripComplaintContext> getContext(int bookingId) async =>
      PostTripComplaintContext(
        bookingId: bookingId,
        bookingCode: 'BK-42',
        tourTitle: 'Test tour',
        endAtUtc: DateTime.utc(2026, 11, 15),
        submissionDeadlineUtc: DateTime.utc(2026, 11, 18),
        canSubmit: true,
        canAmendEvidence: false,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('320px form with keyboard and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository();
      final cubit = PostTripComplaintCubit(
        bookingId: 42,
        getContext: GetPostTripComplaintContext(repository),
        submit: SubmitPostTripComplaint(repository),
        amend: AmendPostTripComplaintEvidence(repository),
        download: DownloadPostTripComplaintEvidence(repository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: child!,
          ),
          home: BlocProvider.value(
            value: cubit,
            child: const PostTripComplaintPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byType(DropdownButtonFormField<PostTripComplaintReasonCategory>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Itinerary not as advertised').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Service quality issue');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Submit complaint'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
