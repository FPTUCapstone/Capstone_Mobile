import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/create_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/get_booking_contact_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/quote_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_state.dart';

import '../support_chat/support_chat_transport_test.dart' show TokenStorage;

void main() {
  for (final initialAdults in <int?>[2, null]) {
    test(
      'real quote request uses selected schedule and ${initialAdults ?? 'default'} adults only',
      () async {
        final client = DioClient(
          config: AppConfig(
            environment: Environment.development,
            apiBaseUrl: Uri.parse('https://api.test.invalid'),
          ),
          secureStorage: TokenStorage(),
        );
        final adapter = _QuoteAdapter(initialAdults ?? 1);
        client.dio.httpClientAdapter = adapter;
        final repository = BookingRepositoryImpl(
          DioBookingRemoteDataSource(client),
        );
        final cubit = BookTourCubit(
          tourScheduleId: '123',
          initialAdultCount: initialAdults,
          quoteBooking: QuoteBookingUseCase(repository),
          createBooking: CreateBookingUseCase(repository),
          getBookingContact: GetBookingContactUseCase(repository),
        );
        addTearDown(() async {
          await cubit.close();
          client.dio.close(force: true);
        });
        if (cubit.state.quoteStatus != QuoteStatus.ready) {
          await cubit.stream.firstWhere(
            (state) =>
                state.quoteStatus == QuoteStatus.ready ||
                state.quoteStatus == QuoteStatus.failure,
          );
        }
        expect(cubit.state.quoteStatus, QuoteStatus.ready);
        final request = adapter.requests.singleWhere(
          (request) => request.path.endsWith('/quote'),
        );
        expect(request.method, 'POST');
        expect(request.data, {
          'tourScheduleId': '123',
          'participantCounts': {
            'adult': initialAdults ?? 1,
            'child': 0,
            'infant': 0,
          },
        });
        final quote = cubit.state.quote!;
        expect(quote.tourScheduleId, '123');
        expect(quote.participantCounts.total, initialAdults ?? 1);
        expect(quote.participantCounts.child, 0);
        expect(quote.participantCounts.infant, 0);
        expect(quote.totalAmount, initialAdults == 2 ? 2000000 : 1000000);
        expect(cubit.state.agreedToTerms, isFalse);
        expect(cubit.state.canSubmit, isFalse);
        expect(
          adapter.requests
              .where((request) => request.method == 'POST')
              .map((request) => request.path),
          ['/api/v1/traveler/tour-bookings/quote'],
        );
      },
    );
  }
}

class _QuoteAdapter implements HttpClientAdapter {
  _QuoteAdapter(this.adults);
  final int adults;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.path.endsWith('/quote')
        ? {
            'tourId': '45',
            'tourScheduleId': '123',
            'currency': 'VND',
            'participantCounts': {'adult': adults, 'child': 0, 'infant': 0},
            'priceBreakdown': [
              {
                'participantType': 'Adult',
                'quantity': adults,
                'unitPrice': 1000000,
                'lineAmount': adults * 1000000,
              },
            ],
            'subtotalAmount': adults * 1000000,
            'discountAmount': 0,
            'totalAmount': adults * 1000000,
            'remainingSlots': 5,
          }
        : {'fullName': 'Traveler', 'phoneNumber': '0912345678'};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
