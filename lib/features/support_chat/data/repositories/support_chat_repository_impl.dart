import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/support_chat/data/datasources/support_chat_remote_data_source.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/repositories/support_chat_repository.dart';

final class SupportChatRepositoryImpl implements SupportChatRepository {
  const SupportChatRepositoryImpl(this._remote);

  final SupportChatRemoteDataSource _remote;

  @override
  Future<SupportChatReply> send({
    required String message,
    required List<SupportChatMessage> history,
    SupportChatContext? context,
    Future<void>? cancellation,
  }) async {
    try {
      final reply = (await _remote.send(
        message: message,
        history: history,
        context: context,
        cancellation: cancellation,
      )).toDomain();
      if (reply.context case final returned?) {
        if (context == null ||
            returned.kind != context.kind ||
            BigInt.tryParse(returned.id) != BigInt.tryParse(context.id)) {
          throw const FormatException('Unexpected support context.');
        }
      }
      return reply;
    } catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const ServerFailure(
          'Support is temporarily unavailable. Please try again.',
        );
      }
      // Do not expose arbitrary ProblemDetails titles, details or field values.
      if (error is DioException && error.response?.statusCode == 400) {
        throw const ValidationFailure(
          'Please check your message and selected context.',
        );
      }
      throw ErrorMapper.toFailure(error);
    }
  }
}
