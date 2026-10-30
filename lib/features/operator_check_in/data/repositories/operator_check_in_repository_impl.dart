import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/models/operator_check_in_json.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';

final class OperatorCheckInRepositoryImpl implements OperatorCheckInRepository {
  const OperatorCheckInRepositoryImpl(this._client);

  final DioClient _client;

  static const _base = '/api/v1/operator/check-in';

  @override
  Future<List<OperatorDepartureSummary>> getTodayDepartures({
    DateTime? targetDate,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (targetDate != null) {
      final formatted =
          '${targetDate.year.toString().padLeft(4, '0')}-'
          '${targetDate.month.toString().padLeft(2, '0')}-'
          '${targetDate.day.toString().padLeft(2, '0')}';
      queryParameters['targetDate'] = formatted;
    }

    try {
      final response = await _client.dio.get<dynamic>(
        '$_base/departures',
        queryParameters: queryParameters,
      );
      return OperatorCheckInJson.departureSummaryList(response.data);
    } on DioException catch (e) {
      throw _parseFailure(e);
    } catch (_) {
      throw const CheckInFailure(kind: CheckInFailureKind.system);
    }
  }

  @override
  Future<DepartureProgress> getDepartureProgress(int scheduleId) async {
    try {
      final response = await _client.dio.get<dynamic>(
        '$_base/schedules/$scheduleId/progress',
      );
      return OperatorCheckInJson.departureProgress(response.data);
    } on DioException catch (e) {
      throw _parseFailure(e);
    } catch (_) {
      throw const CheckInFailure(kind: CheckInFailureKind.system);
    }
  }

  @override
  Future<CheckInResult> scanCheckIn({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    final payload = <String, dynamic>{
      'scheduleId': scheduleId,
      if (qrContent != null && qrContent.isNotEmpty) 'qrContent': qrContent,
      if (bookingCode != null && bookingCode.isNotEmpty)
        'bookingCode': bookingCode,
      'latitude': ?latitude,
      'longitude': ?longitude,
    };

    try {
      final response = await _client.dio.post<dynamic>(
        '$_base/scan',
        data: payload,
      );
      return OperatorCheckInJson.checkInResult(response.data);
    } on DioException catch (e) {
      throw _parseFailure(e);
    } catch (e) {
      if (e is CheckInFailure) rethrow;
      throw const CheckInFailure(kind: CheckInFailureKind.system);
    }
  }

  CheckInFailure _parseFailure(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const CheckInFailure(
        kind: CheckInFailureKind.network,
        message: 'Network connection issue. Please verify your connection.',
      );
    }

    final data = error.response?.data;
    final map = _asMap(data);
    final errorCode = (map['errorCode'] ?? map['ErrorCode'] ?? map['title'])
        ?.toString();
    final message = (map['detail'] ?? map['title'] ?? map['message'])
        ?.toString();

    DateTime? checkedInAt;
    final checkedInAtRaw = map['checkedInAt'] ?? map['CheckedInAt'];
    if (checkedInAtRaw is String) {
      checkedInAt = DateTime.tryParse(checkedInAtRaw)?.toUtc();
    }

    final ticketCode = (map['ticketCode'] ?? map['TicketCode'])?.toString();
    final bookingCode = (map['bookingCode'] ?? map['BookingCode'])?.toString();
    final passengerName = (map['passengerName'] ?? map['PassengerName'])
        ?.toString();

    final kind = switch (errorCode) {
      'checkin.unauthorized' => CheckInFailureKind.unauthorized,
      'checkin.forbidden' => CheckInFailureKind.forbidden,
      'checkin.schedule_not_found' => CheckInFailureKind.scheduleNotFound,
      'checkin.schedule_forbidden' => CheckInFailureKind.scheduleForbidden,
      'checkin.departure_not_today' => CheckInFailureKind.departureNotToday,
      'checkin.invalid_qr' => CheckInFailureKind.invalidQr,
      'checkin.ticket_not_found' => CheckInFailureKind.ticketNotFound,
      'checkin.wrong_schedule' => CheckInFailureKind.wrongSchedule,
      'checkin.booking_cancelled' => CheckInFailureKind.bookingCancelled,
      'checkin.booking_not_confirmed' => CheckInFailureKind.bookingNotConfirmed,
      'checkin.already_used' => CheckInFailureKind.alreadyUsed,
      'checkin.ticket_invalid' => CheckInFailureKind.ticketInvalid,
      'checkin.invalid_input' => CheckInFailureKind.invalidInput,
      _ => _kindFromStatus(error.response?.statusCode),
    };

    return CheckInFailure(
      kind: kind,
      message: message,
      checkedInAt: checkedInAt,
      ticketCode: ticketCode,
      bookingCode: bookingCode,
      passengerName: passengerName,
    );
  }

  CheckInFailureKind _kindFromStatus(int? statusCode) => switch (statusCode) {
    401 => CheckInFailureKind.unauthorized,
    403 => CheckInFailureKind.forbidden,
    404 => CheckInFailureKind.scheduleNotFound,
    409 => CheckInFailureKind.alreadyUsed,
    _ => CheckInFailureKind.system,
  };

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }
}
