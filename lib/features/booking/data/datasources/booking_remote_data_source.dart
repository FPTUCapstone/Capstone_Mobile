import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/booking/data/models/booking_contact_model.dart';
import 'package:trip_mate_mobile/features/booking/data/models/booking_parsers.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_contact.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';

abstract interface class BookingRemoteDataSource {
  Future<BookingContact> getBookingContact();

  Future<BookingQuote> quote({
    required String tourScheduleId,
    required ParticipantCounts participantCounts,
    String? voucherCode,
  });

  Future<TourBooking> createBooking({
    required String tourScheduleId,
    required List<BookingParticipant> participants,
    required String idempotencyKey,
    String? voucherCode,
  });
}

final class DioBookingRemoteDataSource implements BookingRemoteDataSource {
  DioBookingRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;

  static const _bookingsPath = '/api/v1/traveler/tour-bookings';

  @override
  Future<BookingContact> getBookingContact() async {
    final response = await _dio.get<Object?>('/api/v1/traveler/profile');
    return BookingContactModel.fromJson(response.data).toDomain();
  }

  @override
  Future<BookingQuote> quote({
    required String tourScheduleId,
    required ParticipantCounts participantCounts,
    String? voucherCode,
  }) async {
    final response = await _dio.post<Object?>(
      '$_bookingsPath/quote',
      data: {
        'tourScheduleId': tourScheduleId,
        'participantCounts': participantCounts.toJson(),
        'voucherCode': ?voucherCode,
      },
    );
    return parseBookingQuote(response.data);
  }

  @override
  Future<TourBooking> createBooking({
    required String tourScheduleId,
    required List<BookingParticipant> participants,
    required String idempotencyKey,
    String? voucherCode,
  }) async {
    final response = await _dio.post<Object?>(
      _bookingsPath,
      data: {
        'tourScheduleId': tourScheduleId,
        'participants': [for (final p in participants) p.toJson()],
        'voucherCode': ?voucherCode,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return parseTourBooking(response.data);
  }
}
