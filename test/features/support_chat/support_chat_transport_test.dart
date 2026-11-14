import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/support_chat/data/datasources/support_chat_remote_data_source.dart';
import 'package:trip_mate_mobile/features/support_chat/data/repositories/support_chat_repository_impl.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';

void main() {
  late DioClient client;
  late RecordingAdapter adapter;
  late SupportChatRepositoryImpl repository;
  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: TokenStorage(),
    );
    adapter = RecordingAdapter();
    client.dio.httpClientAdapter = adapter;
    repository = SupportChatRepositoryImpl(SupportChatRemoteDataSource(client));
  });
  tearDown(() => client.dio.close(force: true));
  test('conversation cancellation reaches the HTTP request', () async {
    final cancellation = Completer<void>();
    adapter.started = Completer<void>();
    adapter.responseGate = Completer<void>();
    final request = repository.send(
      message: 'Private question',
      history: const [],
      cancellation: cancellation.future,
    );
    final assertion = expectLater(request, throwsA(isA<Failure>()));
    await adapter.started!.future;
    cancellation.complete();
    await assertion;
    expect(adapter.request!.cancelToken!.isCancelled, isTrue);
    adapter.responseGate!.complete();
  });
  test(
    'posts exact authenticated direct contract and optional context',
    () async {
      await repository.send(
        message: 'Help',
        history: const [
          SupportChatMessage(role: 'assistant', content: 'Hello'),
        ],
        context: const SupportChatContext(kind: 'refund', id: '15'),
      );
      expect(adapter.request?.path, '/api/v1/support-chat/messages');
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.receiveTimeout, const Duration(seconds: 65));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(adapter.request?.headers['Authorization'], 'Bearer test-token');
      expect(adapter.request?.data, {
        'message': 'Help',
        'history': [
          {'role': 'assistant', 'content': 'Hello'},
        ],
        'context': {'kind': 'refund', 'id': '15'},
      });
      await repository.send(message: 'Help', history: const []);
      expect(adapter.request?.data, {'message': 'Help', 'history': []});
    },
  );
  for (final entry in <int, Type>{
    400: ValidationFailure,
    401: AuthenticationFailure,
    403: PermissionFailure,
    404: NotFoundFailure,
    429: RateLimitFailure,
    503: ServerFailure,
  }.entries) {
    test('maps ProblemDetails ${entry.key} safely', () async {
      adapter.status = entry.key;
      adapter.body =
          '{"title":"secret implementation detail","detail":"secret","errors":{"message":["secret"]}}';
      try {
        await repository.send(message: 'help', history: const []);
        fail('Expected failure');
      } on Failure catch (failure) {
        expect(failure.runtimeType, entry.value);
        expect(failure.message, isNot(contains('secret')));
      }
    });
  }
  test('malformed API response becomes a safe server failure', () async {
    adapter.body = '{"answer":1,"sources":[]}';
    await expectLater(
      repository.send(message: 'help', history: const []),
      throwsA(isA<ServerFailure>()),
    );
  });
  test(
    'rejects response context differing from explicitly requested record',
    () async {
      for (final context in [
        null,
        const SupportChatContext(kind: 'refund', id: '8'),
        const SupportChatContext(kind: 'itinerary', id: '7'),
      ]) {
        adapter.body =
            '{"answer":"wrong record","sources":[],"context":{"kind":"refund","id":"7"}}';
        await expectLater(
          repository.send(message: 'help', history: const [], context: context),
          throwsA(isA<ServerFailure>()),
        );
      }
    },
  );
  test('accepts normalized response IDs for leading-zero request IDs', () async {
    adapter.body =
        '{"answer":"right record","sources":[],"context":{"kind":"refund","id":"7"}}';
    final reply = await repository.send(
      message: 'help',
      history: const [],
      context: const SupportChatContext(kind: 'refund', id: '0007'),
    );
    expect(reply.answer, 'right record');
  });
  test('accepts explicit null context for general help', () async {
    adapter.body = '{"answer":"general help","sources":[],"context":null}';
    expect(
      (await repository.send(message: 'help', history: const [])).context,
      isNull,
    );
  });
  test(
    'tour actions stay in memory while outbound history carries only text',
    () async {
      adapter.body =
          '{"answer":"Tour details","sources":[],"context":{"kind":"tour","id":"7"},"actions":[{"type":"navigate","label":"View tour","url":"/tours/7"}]}';
      final reply = await repository.send(
        message: 'Tour details',
        history: const [],
        context: const SupportChatContext(kind: 'tour', id: '0007'),
      );
      expect(reply.actions.single.url, '/tours/7');
      await repository.send(
        message: 'Next question',
        context: const SupportChatContext(kind: 'tour', id: '7'),
        history: [
          SupportChatMessage(
            role: 'assistant',
            content: reply.answer,
            actions: reply.actions,
          ),
        ],
      );
      expect((adapter.request!.data as Map)['history'], [
        {'role': 'assistant', 'content': 'Tour details'},
      ]);
      await expectLater(
        repository.send(
          message: 'Wrong tour',
          history: const [],
          context: const SupportChatContext(kind: 'tour', id: '8'),
        ),
        throwsA(isA<ServerFailure>()),
      );
    },
  );
  test('connection failure becomes network failure', () async {
    adapter.networkFailure = true;
    await expectLater(
      repository.send(message: 'help', history: const []),
      throwsA(isA<NetworkFailure>()),
    );
  });
}

class TokenStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? 'test-token' : null;
}

class RecordingAdapter implements HttpClientAdapter {
  Completer<void>? started;
  Completer<void>? responseGate;
  RequestOptions? request;
  var status = 200;
  var body = '{"answer":"Help","sources":[]}';
  var networkFailure = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    started?.complete();
    await responseGate?.future;
    if (networkFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
