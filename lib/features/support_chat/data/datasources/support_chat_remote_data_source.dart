import 'dart:async';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/support_chat/data/models/support_chat_response_model.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';

final class SupportChatRemoteDataSource {
  const SupportChatRemoteDataSource(this._client);

  final DioClient _client;

  Future<SupportChatResponseModel> send({
    required String message,
    required List<SupportChatMessage> history,
    SupportChatContext? context,
    Future<void>? cancellation,
  }) async {
    final cancelToken = CancelToken();
    unawaited(
      cancellation?.then(
        (_) => cancelToken.cancel('Support conversation ended.'),
      ),
    );
    final response = await _client.dio.post<Object?>(
      '/api/v1/support-chat/messages',
      options: Options(receiveTimeout: const Duration(seconds: 65)),
      cancelToken: cancelToken,
      data: {
        'message': message,
        'history': history
            .map((entry) => {'role': entry.role, 'content': entry.content})
            .toList(),
        if (context != null)
          'context': {'kind': context.kind, 'id': context.id},
      },
    );
    return SupportChatResponseModel.fromJson(response.data);
  }
}
