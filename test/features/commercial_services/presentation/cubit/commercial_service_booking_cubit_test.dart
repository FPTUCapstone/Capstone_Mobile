import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_booking_request.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_booking_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_booking_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';

void main() {
  final fixedNowUtc = DateTime.utc(2026, 10, 10, 5, 0);

  setUp(() {
    DemoCommercialServiceStore.instance.reset();
  });

  group('CommercialServiceBookingCubit - Production mode', () {
    test(
      'Production mode emits pendingIntegration, returns null demoPreviewEstimatedAmountVnd (BR-63), and refuses to create fake bookings',
      () async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: false,
          nowUtcProvider: () => fixedNowUtc,
        );

        await cubit.load(poiId: 901);

        expect(
          cubit.state.status,
          CommercialServiceBookingStatus.pendingIntegration,
        );
        expect(cubit.state.demoPreviewEstimatedAmountVnd, isNull);
        expect(cubit.state.activeRequest, isNull);

        cubit.submitRequest();
        expect(
          cubit.state.status,
          CommercialServiceBookingStatus.pendingIntegration,
        );
        expect(cubit.state.activeRequest, isNull);
        expect(DemoCommercialServiceStore.instance.allRequests, isEmpty);
      },
    );
  });

  group('CommercialServiceBookingCubit - Demo mode validations & lifecycle', () {
    test('validates required fields with MSG01', () async {
      final cubit = CommercialServiceBookingCubit(
        isDemoMode: true,
        nowUtcProvider: () => fixedNowUtc,
      );
      await cubit.load(poiId: 901);

      cubit
        ..updateContactFullName('   ')
        ..updateContactPhoneNumber('')
        ..updateContactEmail('');
      cubit.submitRequest();

      expect(cubit.state.validationMessage, CommercialServiceMessages.msg01);
      expect(
        cubit.state.fieldErrors['contactFullName'],
        CommercialServiceMessages.msg01,
      );
      expect(
        cubit.state.fieldErrors['contactPhoneNumber'],
        CommercialServiceMessages.msg01,
      );
      expect(
        cubit.state.fieldErrors['contactEmail'],
        CommercialServiceMessages.msg01,
      );
      expect(cubit.state.activeRequest, isNull);
    });

    test(
      'validates past requested date against Vietnam planning wall-clock date with MSG76',
      () async {
        // 2026-10-10T20:00Z is 2026-10-11 03:00 in UTC+7.
        // Therefore 2026-10-10 is already in the past in Vietnam wall-clock time.
        final lateUtc = DateTime.utc(2026, 10, 10, 20, 0);
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => lateUtc,
        );
        await cubit.load(poiId: 901);

        cubit.updateRequestedDate('2026-10-10');
        cubit.submitRequest();

        expect(cubit.state.validationMessage, CommercialServiceMessages.msg76);
        expect(
          cubit.state.fieldErrors['requestedDate'],
          CommercialServiceMessages.msg76,
        );
        expect(cubit.state.activeRequest, isNull);
      },
    );

    test(
      'blocks submission with MSG75 when service is closed for booking (BR-88)',
      () async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);

        cubit.toggleSimulateServiceClosed(true);
        cubit.submitRequest();

        expect(cubit.state.validationMessage, CommercialServiceMessages.msg75);
        expect(cubit.state.activeRequest, isNull);
      },
    );

    test(
      'blocks submission with MSG70 when requested date or time slot is not available (BR-88)',
      () async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);

        cubit.updateRequestedTime('03:30');
        cubit.submitRequest();

        expect(cubit.state.validationMessage, CommercialServiceMessages.msg70);
        expect(
          cubit.state.fieldErrors['availability'],
          CommercialServiceMessages.msg70,
        );
        expect(cubit.state.activeRequest, isNull);
      },
    );

    test(
      'blocks submission with MSG71 when requested quantity exceeds available quantity (BR-88)',
      () async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);

        // Deluxe River View King has availableQuantity = 4.
        cubit.updateQuantity(5);
        cubit.submitRequest();

        expect(cubit.state.validationMessage, CommercialServiceMessages.msg71);
        expect(
          cubit.state.fieldErrors['quantity'],
          CommercialServiceMessages.msg71,
        );
        expect(cubit.state.activeRequest, isNull);
      },
    );

    test(
      'emits failure with MSG127 when system failure is simulated',
      () async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);

        cubit.toggleSimulateSystemFailure(true);
        cubit.submitRequest();

        expect(cubit.state.status, CommercialServiceBookingStatus.failure);
        expect(cubit.state.errorMessage, CommercialServiceMessages.msg127);
        expect(cubit.state.activeRequest, isNull);
      },
    );

    test(
      'creates Pending Confirmation request (MSG69) and supports Confirm (MSG72), Reject (MSG73), and Cancel (MSG74) transitions (BR-89, V2 status lifecycle)',
      () async {
        final cubit = CommercialServiceBookingCubit(
          isDemoMode: true,
          nowUtcProvider: () => fixedNowUtc,
        );
        await cubit.load(poiId: 901);
        cubit.updateQuantity(2);

        expect(cubit.state.demoPreviewEstimatedAmountVnd, 2900000);

        cubit.submitRequest();
        expect(
          cubit.state.status,
          CommercialServiceBookingStatus.requestActive,
        );
        expect(cubit.state.statusMessage, CommercialServiceMessages.msg69);
        expect(
          cubit.state.activeRequest!.status,
          CommercialBookingStatus.pendingConfirmation,
        );

        // Provider confirms -> Confirmed + MSG72
        cubit.simulateProviderConfirm();
        expect(
          cubit.state.activeRequest!.status,
          CommercialBookingStatus.confirmed,
        );
        expect(cubit.state.statusMessage, CommercialServiceMessages.msg72);

        // Start a second request to test Provider Reject -> Rejected + MSG73
        cubit.startNewRequest();
        cubit.submitRequest();
        expect(
          cubit.state.activeRequest!.status,
          CommercialBookingStatus.pendingConfirmation,
        );
        cubit.simulateProviderReject();
        expect(
          cubit.state.activeRequest!.status,
          CommercialBookingStatus.rejected,
        );
        expect(cubit.state.statusMessage, CommercialServiceMessages.msg73);

        // Start a third request to test Traveler Cancel -> Cancelled + MSG74
        cubit.startNewRequest();
        cubit.submitRequest();
        cubit.cancelPendingRequest();
        expect(
          cubit.state.activeRequest!.status,
          CommercialBookingStatus.cancelled,
        );
        expect(cubit.state.statusMessage, CommercialServiceMessages.msg74);
      },
    );
  });
}
