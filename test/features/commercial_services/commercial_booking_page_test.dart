import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_page.dart';

void main() {
  testWidgets('submits a selected service and shows its pending receipt', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => CommercialBookingCubit(repository),
          child: const CommercialBookingPage(poiId: 352, itineraryId: 11),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<CommercialOption>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Double room').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<CommercialSlot>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('27/11/2026 · 14:00').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Traveler Contact');
    await tester.enterText(fields.at(1), '0901234567');
    await tester.enterText(fields.at(2), 'traveler@example.test');
    final send = find.text('Gửi yêu cầu');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận gửi'));
    await tester.pumpAndSettle();

    expect(repository.request?.serviceId, 3);
    expect(repository.request?.itineraryId, 11);
    expect(repository.request?.startsAt, DateTime.utc(2026, 11, 27, 7));
    expect(repository.key, isNotEmpty);
    expect(find.text('Yêu cầu SR-42'), findsOneWidget);
    expect(find.text('Chờ nhà cung cấp xác nhận'), findsOneWidget);
  });
}

final class _Repository implements CommercialBookingRepository {
  CommercialBookingRequest? request;
  String? key;

  @override
  Future<List<CommercialOption>> options(int poiId) async => [
    (id: 3, name: 'Double room', priceAmount: 120000),
  ];

  @override
  Future<List<CommercialSlot>> availability(int serviceId) async => [
    (startsAt: DateTime.utc(2026, 11, 27, 7), remainingQuantity: 2),
  ];

  @override
  Future<CommercialBookingReceipt> submit(
    CommercialBookingRequest request,
    String key,
  ) async {
    this.request = request;
    this.key = key;
    return (
      requestCode: 'SR-42',
      status: 'PendingConfirmation',
      estimatedAmount: 120000,
    );
  }
}
