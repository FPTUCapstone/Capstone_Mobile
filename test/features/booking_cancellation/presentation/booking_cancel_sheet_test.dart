import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/cubit/booking_cancellation_cubit.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/widgets/booking_cancel_sheet.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/resources/booking_cancellation_en.dart';

import 'booking_cancellation_cubit_test.dart'
    show FakeBookingCancellationRepository, buildCubit, preview;

/// Hosts the sheet the way `BookingCancelSheet.show` does, but with a manually built
/// cubit (bypassing DI), mirroring `trip_record_detail_sheet_test.dart`.
Future<void> _open(
  WidgetTester tester,
  BookingCancellationCubit cubit, {
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => BlocProvider.value(
                  value: cubit..load(),
                  child: const BookingCancelSheet(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeBookingCancellationRepository repository;

  setUp(() {
    repository = FakeBookingCancellationRepository();
  });

  testWidgets(
    'shows the refund amount and submits without a checkbox when the refund is above zero',
    (tester) async {
      repository.previewReads.add(preview());
      repository.cancelCalls.add(null);
      final cubit = buildCubit(repository);
      addTearDown(cubit.close);

      await _open(tester, cubit);

      expect(find.textContaining('300'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(
        find.widgetWithText(FilledButton, BookingCancellationStrings.confirm),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BookingCancelSheet), findsNothing);
    },
  );

  testWidgets(
    'requires ticking the confirmation before a zero-refund cancellation is sent',
    (tester) async {
      repository.previewReads.add(
        preview(
          blockingReasonCode: 'booking.cancellation.confirmation_required',
          estimatedRefundAmount: 0,
        ),
      );
      repository.cancelCalls.add(null);
      final cubit = buildCubit(repository);
      addTearDown(cubit.close);

      await _open(tester, cubit);

      final confirmButton = find.widgetWithText(
        FilledButton,
        BookingCancellationStrings.confirm,
      );
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.byType(BookingCancelSheet), findsNothing);
    },
  );

  testWidgets('blocks submission when the booking cannot be cancelled at all', (
    tester,
  ) async {
    repository.previewReads.add(preview(canCancel: false));
    final cubit = buildCubit(repository);
    addTearDown(cubit.close);

    await _open(tester, cubit);

    final confirmButton = find.widgetWithText(
      FilledButton,
      BookingCancellationStrings.confirm,
    );
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
  });

  testWidgets('shows an error message when the cancellation fails', (
    tester,
  ) async {
    repository.previewReads.add(preview());
    repository.cancelCalls.add(
      const BookingCancellationFailure(BookingCancellationFailureKind.system),
    );
    final cubit = buildCubit(repository);
    addTearDown(cubit.close);

    await _open(tester, cubit);

    await tester.tap(
      find.widgetWithText(FilledButton, BookingCancellationStrings.confirm),
    );
    await tester.pumpAndSettle();

    expect(find.text(BookingCancellationStrings.system), findsOneWidget);
    expect(find.text(BookingCancellationStrings.cancelled), findsNothing);
  });
}
