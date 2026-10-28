import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/in_app_notification_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/in_app_notification_repository.dart';

final class InAppNotificationRepositoryImpl
    implements InAppNotificationRepository {
  const InAppNotificationRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  static const _path = '/api/v1/notifications';
  final DioClient _dioClient;

  @override
  Future<InAppNotificationPage> getInbox({
    bool unreadOnly = false,
    int limit = 20,
    int? beforeId,
  }) async {
    if (limit < 1 || limit > 50 || (beforeId != null && beforeId <= 0)) {
      throw ArgumentError('Invalid notification pagination.');
    }
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {
          'unreadOnly': unreadOnly,
          'limit': limit,
          'beforeId': ?beforeId,
        },
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty inbox response.');
      final rawItems = data['items'] as List<dynamic>;
      return InAppNotificationPage(
        items: rawItems
            .map(
              (item) => InAppNotificationModel.fromJson(
                item as Map<String, dynamic>,
              ).toEntity(),
            )
            .toList(growable: false),
        nextBeforeId: (data['nextBeforeId'] as num?)?.toInt(),
      );
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<void> markRead(int notificationId) async {
    if (notificationId <= 0) throw ArgumentError.value(notificationId);
    try {
      final response = await _dioClient.dio.post<void>(
        '$_path/$notificationId/read',
      );
      if (response.statusCode != 204) {
        throw const FormatException('Invalid mark-read response.');
      }
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
