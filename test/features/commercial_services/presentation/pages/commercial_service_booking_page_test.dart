import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_booking_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/pages/commercial_service_booking_page.dart';

Widget _wrapWithCubit(
  CommercialServiceBookingCubit cubit, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: BlocProvider.value(
      value: cubit,
      child: const CommercialServiceBookingPage(),
    ),
  );
}

void main() {
  final fixedNowUtc = DateTime.utc(2026, 10, 10, 5, 0);

  setUp(() {
    DemoCommercialServiceStore.instance.reset();
  });

  group(
    'CommercialServiceBookingPage - Production truthfulness (NO_BACKEND)',
    () {
      testWidgets(
        'renders Pending Server Integration banner, BR-63 pending amount text, and disabled Submit Request button',
        (tester) async {
          final cubit = CommercialServiceBookingCubit(
            isDemoMode: false,
            nowUtcProvider: () => fixedNowUtc,
          );
          await cubit.load(poiId: 901);

          await tester.pumpWidget(_wrapWithCubit(cubit));
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const Key('commercial_booking_production_pending_banner'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('commercial_booking_amount_pending_text')),
            findsOneWidget,
          );

          final submitButton = tester.widget<FilledButton>(
            find.byKey(const Key('commercial_booking_submit_button')),
          );
          expect(submitButton.onPressed, isNull);
          expect(DemoCommercialServiceStore.instance.allRequests, isEmpty);
        },
      );
    },
  );

  group('CommercialServiceBookingPage - Demo CR-05 dialogs & lifecycle', () {
    testWidgets(
      'opens CR-05 confirmation dialog on Submit Request, creates Pending Confirmation (MSG69), and supports Cancel (MSG74 + BR-76)',
      (tester) async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_booking_demo_amount_value')),
          findsOneWidget,
        );
        expect(find.text('₫1,450,000'), findsOneWidget);

        // Increase quantity -> 2 -> ₫2,900,000
        final incFinder = find.byKey(
          const Key('commercial_booking_quantity_increment'),
        );
        await tester.ensureVisible(incFinder);
        await tester.tap(incFinder);
        await tester.pumpAndSettle();
        expect(find.text('₫2,900,000'), findsOneWidget);

        // Tap Submit Request -> CR-05 dialog appears
        final submitFinder = find.byKey(
          const Key('commercial_booking_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_booking_submit_confirm_dialog')),
          findsOneWidget,
        );

        // Cancel dialog first -> no request created
        await tester.tap(
          find.byKey(const Key('commercial_booking_confirm_dialog_cancel')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('commercial_booking_active_request_card')),
          findsNothing,
        );

        // Tap Submit Request again and confirm
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('commercial_booking_confirm_dialog_accept')),
        );
        await tester.pumpAndSettle();

        // Request active with Pending Confirmation + MSG69
        expect(
          find.byKey(const Key('commercial_booking_active_request_card')),
          findsOneWidget,
        );
        expect(find.text(CommercialServiceMessages.msg69), findsOneWidget);
        expect(find.text('Pending Confirmation'), findsOneWidget);

        // Tap Cancel Pending Request -> CR-05 cancel dialog appears
        final cancelBtnFinder = find.byKey(
          const Key('commercial_booking_cancel_request_button'),
        );
        await tester.ensureVisible(cancelBtnFinder);
        await tester.tap(cancelBtnFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_booking_cancel_confirm_dialog')),
          findsOneWidget,
        );

        // Confirm cancellation -> Cancelled + MSG74 + BR-76 refund notice
        await tester.tap(
          find.byKey(const Key('commercial_booking_cancel_dialog_accept')),
        );
        await tester.pumpAndSettle();

        expect(find.text(CommercialServiceMessages.msg74), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(
          find.byKey(const Key('commercial_booking_br76_refund_notice')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'supports provider Confirm (MSG72 + PC-03 itinerary reflection) and Reject (MSG73) simulations',
      (tester) async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 902);
        cubit.submitRequest();

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        final confirmSimFinder = find.byKey(
          const Key('commercial_booking_simulate_confirm_button'),
        );
        await tester.ensureVisible(confirmSimFinder);
        await tester.tap(confirmSimFinder);
        await tester.pumpAndSettle();

        expect(find.text(CommercialServiceMessages.msg72), findsOneWidget);
        expect(find.text('Confirmed'), findsOneWidget);
        expect(
          find.byKey(const Key('commercial_booking_itinerary_reflection_note')),
          findsOneWidget,
        );

        // Start new request and simulate provider reject
        cubit.startNewRequest();
        cubit.submitRequest();
        await tester.pumpAndSettle();

        final rejectSimFinder = find.byKey(
          const Key('commercial_booking_simulate_reject_button'),
        );
        await tester.ensureVisible(rejectSimFinder);
        await tester.tap(rejectSimFinder);
        await tester.pumpAndSettle();

        expect(find.text(CommercialServiceMessages.msg73), findsOneWidget);
        expect(find.text('Rejected'), findsOneWidget);
        expect(
          find.byKey(const Key('commercial_booking_new_request_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly across 360x640, 390x844, 412x915 viewports and 200% text scale without RenderFlex overflow',
      (tester) async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);

        for (final size in const [
          Size(360, 640),
          Size(390, 844),
          Size(412, 915),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(_wrapWithCubit(cubit));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await tester.binding.setSurfaceSize(const Size(360, 640));
        await tester.pumpWidget(_wrapWithCubit(cubit, textScale: 2.0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
