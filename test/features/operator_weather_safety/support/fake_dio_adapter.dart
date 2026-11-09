import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Replays queued HTTP answers and records every request it receives.
final class FakeDioAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _answers = <Object>[];

  void reply(int status, [Object? body]) => _answers.add(_Answer(status, body));

  void failWith(DioExceptionType type) => _answers.add(type);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final answer = _answers.removeAt(0);
    if (answer is DioExceptionType) {
      throw DioException(requestOptions: options, type: answer);
    }
    answer as _Answer;
    return ResponseBody.fromString(
      answer.body == null ? '' : jsonEncode(answer.body),
      answer.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Answer {
  const _Answer(this.status, this.body);
  final int status;
  final Object? body;
}
