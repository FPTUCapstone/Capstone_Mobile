import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/navigation_session_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';

final class NavigationSessionRepositoryImpl
    implements NavigationSessionRepository {
  const NavigationSessionRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  static const _itineraryPath = '/api/v1/itineraries';
  static const _sessionPath = '/api/v1/navigation-sessions';
  final DioClient _dioClient;

  @override
  Future<NavigationSession> start({
    required int itineraryId,
    required String idempotencyKey,
  }) => _send(
    () => _dioClient.dio.post<Map<String, dynamic>>(
      '$_itineraryPath/$itineraryId/navigation-sessions',
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
  );

  @override
  Future<NavigationSession> getById(int sessionId) => _send(
    () => _dioClient.dio.get<Map<String, dynamic>>('$_sessionPath/$sessionId'),
  );

  @override
  Future<NavigationSession> reachItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  }) => _send(
    () => _dioClient.dio.put<Map<String, dynamic>>(
      '$_sessionPath/$sessionId/reached-items/$itemId',
      data: {'occurredAtUtc': _utc(occurredAt)},
    ),
  );

  @override
  Future<NavigationSession> skipItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  }) => _send(
    () => _dioClient.dio.put<Map<String, dynamic>>(
      '$_sessionPath/$sessionId/skipped-items/$itemId',
      data: {'occurredAtUtc': _utc(occurredAt)},
    ),
  );

  @override
  Future<NavigationSession> depart({
    required int sessionId,
    required DateTime occurredAt,
  }) => _send(
    () => _dioClient.dio.put<Map<String, dynamic>>(
      '$_sessionPath/$sessionId/state',
      data: {'state': 'Navigating', 'occurredAtUtc': _utc(occurredAt)},
    ),
  );

  @override
  Future<NavigationSession> complete(int sessionId) => _send(
    () => _dioClient.dio.put<Map<String, dynamic>>(
      '$_sessionPath/$sessionId/completion',
    ),
  );

  Future<NavigationSession> _send(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty navigation session response.');
      }
      return NavigationSessionModel.fromJson(data);
    } catch (error) {
      throw _toFailure(error);
    }
  }

  static String _utc(DateTime value) => value.toUtc().toIso8601String();

  static Failure _toFailure(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final reason = _reasons[ErrorMapper.extractErrorCode(data)];
      if (reason != null) {
        return NavigationFailure(
          _messages[reason]!,
          reason: reason,
          activeSessionId: _activeSessionId(data),
        );
      }
    }
    return ErrorMapper.toFailure(error);
  }

  static int? _activeSessionId(Object? data) {
    if (data is! Map) return null;
    final extensions = data['extensions'];
    final raw =
        data['activeSessionId'] ??
        (extensions is Map ? extensions['activeSessionId'] : null);
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static const _reasons = <String, NavigationFailureReason>{
    'navigation.active_session_exists':
        NavigationFailureReason.activeSessionExists,
    'navigation.outside_trip_window': NavigationFailureReason.outsideTripWindow,
    'navigation.itinerary_not_active':
        NavigationFailureReason.itineraryNotActive,
    'navigation.no_navigable_items': NavigationFailureReason.noNavigableItems,
    'navigation.itinerary_schedule_incomplete':
        NavigationFailureReason.itineraryScheduleIncomplete,
    'navigation.session_completed': NavigationFailureReason.sessionCompleted,
    'navigation.item_already_reached':
        NavigationFailureReason.itemAlreadyReached,
    'navigation.item_not_navigable': NavigationFailureReason.itemNotNavigable,
    'navigation.session_not_found': NavigationFailureReason.sessionNotFound,
    'navigation.access_denied': NavigationFailureReason.accessDenied,
    'navigation.idempotency_key_payload_mismatch':
        NavigationFailureReason.idempotencyKeyPayloadMismatch,
  };

  static const _messages = <NavigationFailureReason, String>{
    NavigationFailureReason.activeSessionExists:
        'You already have a trip in progress.',
    NavigationFailureReason.outsideTripWindow:
        'This trip can only be navigated during its scheduled time.',
    NavigationFailureReason.itineraryNotActive:
        'Only an Active itinerary can be navigated. Accept the itinerary first.',
    NavigationFailureReason.noNavigableItems:
        'This itinerary has no stops that can be navigated.',
    NavigationFailureReason.itineraryScheduleIncomplete:
        'Some stops have no planned time, so navigation cannot start.',
    NavigationFailureReason.sessionCompleted:
        'This navigation session has already ended.',
    NavigationFailureReason.itemAlreadyReached:
        'This stop was already reached.',
    NavigationFailureReason.itemNotNavigable:
        'This stop is not part of the navigation session.',
    NavigationFailureReason.sessionNotFound:
        'This navigation session no longer exists.',
    NavigationFailureReason.accessDenied:
        'You no longer have access to this trip.',
    NavigationFailureReason.idempotencyKeyPayloadMismatch:
        'A conflicting start request is in progress. Please try again.',
  };
}
