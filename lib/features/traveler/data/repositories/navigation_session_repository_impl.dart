import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/navigation_session_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/reroute_proposal_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/trip_alert_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/weather_advisory_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/rerouting_proposal_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/trip_alert_repository.dart';

final class NavigationSessionRepositoryImpl
    implements
        NavigationSessionRepository,
        TripAlertRepository,
        ReroutingProposalRepository {
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

  @override
  Future<List<TripAlert>> listAlerts(int sessionId) async {
    try {
      final response = await _dioClient.dio.get<List<dynamic>>(
        '$_sessionPath/$sessionId/alerts',
      );
      return (response.data ?? const <dynamic>[])
          .map((item) => TripAlertModel.fromJson(_json(item)))
          .toList(growable: false);
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> acknowledgeAlert({
    required int sessionId,
    required int incidentId,
  }) async {
    try {
      await _dioClient.dio.put<void>(
        '$_sessionPath/$sessionId/alerts/$incidentId/acknowledgement',
      );
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<List<WeatherAdvisory>> listWeatherAdvisories(int sessionId) async {
    try {
      final response = await _dioClient.dio.get<List<dynamic>>(
        '$_sessionPath/$sessionId/weather-advisories',
      );
      return (response.data ?? const <dynamic>[])
          .map((item) => WeatherAdvisoryModel.fromJson(_json(item)))
          .toList(growable: false);
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<TripAlert> reportDeviation({
    required int sessionId,
    required String eventId,
    required DateTime observedAtUtc,
    required int targetItemId,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '$_sessionPath/$sessionId/deviations',
        data: {
          'eventId': eventId,
          'observedAtUtc': _utc(observedAtUtc),
          'targetItemId': targetItemId,
        },
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty alert response.');
      return TripAlertModel.fromJson(data);
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<RerouteProposal> getProposal({
    required int sessionId,
    required int proposalId,
  }) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        _proposalPath(sessionId, proposalId),
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty proposal response.');
      return RerouteProposalModel.fromJson(data);
    } catch (error) {
      throw _toReroutingFailure(error);
    }
  }

  @override
  Future<NavigationSession> acceptProposal({
    required int sessionId,
    required int proposalId,
  }) async {
    try {
      final response = await _dioClient.dio.put<Map<String, dynamic>>(
        '${_proposalPath(sessionId, proposalId)}/acceptance',
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty navigation session response.');
      }
      return NavigationSessionModel.fromJson(data);
    } catch (error) {
      throw _toReroutingFailure(error);
    }
  }

  @override
  Future<void> rejectProposal({
    required int sessionId,
    required int proposalId,
  }) async {
    try {
      await _dioClient.dio.put<void>(
        '${_proposalPath(sessionId, proposalId)}/rejection',
      );
    } catch (error) {
      throw _toReroutingFailure(error);
    }
  }

  static String _proposalPath(int sessionId, int proposalId) =>
      '$_sessionPath/$sessionId/rerouting-proposals/$proposalId';

  static Failure _toReroutingFailure(Object error) {
    if (error is DioException) {
      final reason =
          _reroutingReasons[ErrorMapper.extractErrorCode(error.response?.data)];
      if (reason != null) {
        return ReroutingFailure(_msg44, reason: reason);
      }
    }
    return switch (ErrorMapper.toFailure(error)) {
      ServerFailure() => const ServerFailure(_msg127),
      NetworkFailure() => const NetworkFailure(_msg127),
      final failure => failure,
    };
  }

  static const _msg44 = 'Hiện không có đề xuất đổi lộ trình nào khả dụng.';
  static const _msg127 =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. '
      'Vui lòng kiểm tra kết nối mạng và thử lại.';

  static const _reroutingReasons = <String, ReroutingFailureReason>{
    'rerouting.not_found': ReroutingFailureReason.notFound,
    'rerouting.proposal_expired': ReroutingFailureReason.expired,
    'rerouting.proposal_closed': ReroutingFailureReason.closed,
    'rerouting.proposal_infeasible': ReroutingFailureReason.infeasible,
  };

  static Map<String, dynamic> _json(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Invalid alert response.');
  }

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
    'navigation.session_interrupted':
        NavigationFailureReason.sessionInterrupted,
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
        'Bạn đang có một chuyến đi khác đang diễn ra.',
    NavigationFailureReason.outsideTripWindow:
        'Chỉ có thể dẫn đường chuyến đi này trong khung giờ đã lên lịch.',
    NavigationFailureReason.itineraryNotActive:
        'Chỉ có thể dẫn đường lịch trình đang hoạt động. Vui lòng chấp nhận lịch trình trước.',
    NavigationFailureReason.noNavigableItems:
        'Lịch trình này không có điểm dừng nào để dẫn đường.',
    NavigationFailureReason.itineraryScheduleIncomplete:
        'Một số điểm dừng chưa có thời gian dự kiến nên không thể bắt đầu dẫn đường.',
    NavigationFailureReason.sessionCompleted:
        'Phiên dẫn đường này đã kết thúc.',
    NavigationFailureReason.sessionInterrupted:
        'Chuyến đi này đã tạm dừng vì lý do an toàn.',
    NavigationFailureReason.itemAlreadyReached:
        'Điểm dừng này đã được đánh dấu là đã đến.',
    NavigationFailureReason.itemNotNavigable:
        'Điểm dừng này không thuộc phiên dẫn đường hiện tại.',
    NavigationFailureReason.sessionNotFound:
        'Phiên dẫn đường này không còn tồn tại.',
    NavigationFailureReason.accessDenied:
        'Bạn không còn quyền truy cập chuyến đi này.',
    NavigationFailureReason.idempotencyKeyPayloadMismatch:
        'Đang có một yêu cầu khởi động khác bị xung đột. Vui lòng thử lại.',
  };
}
