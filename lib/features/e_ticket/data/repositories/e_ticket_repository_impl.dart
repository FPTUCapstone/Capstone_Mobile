import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/e_ticket/data/models/e_ticket_json.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/repositories/e_ticket_repository.dart';

final class ETicketRepositoryImpl implements ETicketRepository {
  const ETicketRepositoryImpl(this._client);

  final DioClient _client;

  static const _tickets = '/api/v1/traveler/tickets';

  @override
  Future<ETicket> getTicket(int ticketId) =>
      _send('GET', '$_tickets/$ticketId');

  @override
  Future<ETicket> getBookingTicket(int bookingId) =>
      _send('GET', '/api/v1/traveler/bookings/$bookingId/ticket');

  @override
  Future<ETicket> refreshQr(int ticketId) =>
      _send('POST', '$_tickets/$ticketId/qr-code/refresh');

  Future<ETicket> _send(String method, String path) async {
    final Object? body;
    try {
      final response = await _client.dio.request<String>(
        path,
        options: Options(method: method, responseType: ResponseType.plain),
      );
      body = jsonDecode(response.data ?? '');
    } on DioException catch (error) {
      throw _failure(error);
    } on Object {
      throw const ETicketFailure(ETicketFailureKind.system);
    }
    try {
      return ETicketJson.ticket(body);
    } on Object {
      throw const ETicketFailure(ETicketFailureKind.system);
    }
  }

  /// Only reviewed codes become specific failures; no server text ever reaches the user.
  ETicketFailure _failure(DioException error) {
    final status = error.response?.statusCode;
    final problem = _problem(error.response?.data);
    final code = problem['errorCode'];
    if (status == 401 || code == 'ticket.unauthorized') {
      return const ETicketFailure(ETicketFailureKind.signIn);
    }
    if (status == 403 || code == 'ticket.forbidden') {
      return const ETicketFailure(ETicketFailureKind.forbidden);
    }
    return switch (code) {
      'ticket.not_found' => const ETicketFailure(ETicketFailureKind.notFound),
      'ticket.booking_not_confirmed' => const ETicketFailure(
        ETicketFailureKind.notConfirmed,
      ),
      'ticket.not_issued' => const ETicketFailure(ETicketFailureKind.notIssued),
      'ticket.not_refreshable' => ETicketFailure(
        ETicketFailureKind.notRefreshable,
        ticketStatus: _statusOrNull(problem['ticketStatus']),
      ),
      _ => const ETicketFailure(ETicketFailureKind.system),
    };
  }

  static Map<String, Object?> _problem(Object? data) {
    if (data is! String) return const {};
    try {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on Object {
      return const {};
    }
  }

  static ETicketStatus? _statusOrNull(Object? value) {
    try {
      return ETicketJson.status(value);
    } on FormatException {
      return null;
    }
  }
}
