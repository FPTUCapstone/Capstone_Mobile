import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/messaging/data/datasources/messaging_remote_data_source.dart';
import 'package:trip_mate_mobile/features/messaging/data/repositories/messaging_repository_impl.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'chat_dto_test.dart' show groupMessage;

void main() {
  late MessagingRepository repository;
  late _Adapter adapter;
  const ref = ChatThreadRef(kind: ChatKind.group, id: 7);
  setUp(() {
    final client = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://example.test'),
      ),
      secureStorage: _Storage(),
    );
    adapter = _Adapter();
    client.dio.httpClientAdapter = adapter;
    repository = MessagingRepositoryImpl(MessagingRemoteDataSource(client));
  });
  test(
    'history uses exact absolute route, fixed limit, cursor and ascending page',
    () async {
      adapter.body = [groupMessage()];
      final page = await repository.history(ref, beforeMessageId: 100);
      expect(adapter.request!.uri.path, '/api/v1/travel-groups/7/messages');
      expect(adapter.request!.queryParameters, {
        'limit': 50,
        'beforeMessageId': 100,
      });
      expect(adapter.request!.headers['Authorization'], 'Bearer test-token');
      expect(page.items.single.id, 90);
      expect(page.nextBeforeId, isNull);
    },
  );
  test(
    'send rejects unexpected success status and does not retry mutation',
    () async {
      adapter.body = groupMessage();
      adapter.status = 200;
      await expectLater(
        repository.send(
          thread: ref,
          content: 'Where?',
          type: ChatMessageType.poll,
          clientMessageId: 'b759f92c-8f9f-4ca8-9bea-b1a2edb4c2ed',
        ),
        throwsA(isA<ServerFailure>()),
      );
      expect(adapter.calls, 1);
    },
  );
  test('malformed and mismatched responses become safe failures', () async {
    adapter.body = [
      {...groupMessage(), 'groupId': 999},
    ];
    await expectLater(repository.history(ref), throwsA(isA<ServerFailure>()));
    adapter.body = {'title': 'Secret SQL exception user@example.test'};
    adapter.status = 400;
    try {
      await repository.history(ref);
      fail('must reject');
    } on Failure catch (failure) {
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, isNot(contains('Secret')));
    }
  });
  test(
    'vote cancellation patches older loaded card using confirmed counts',
    () async {
      adapter.body = [groupMessage()];
      final original = (await repository.history(ref)).items.single;
      adapter.body = {'0': 1};
      final patched = await repository.interact(
        message: original,
        action: ChatInteraction.vote,
        optionIndex: -1,
      );
      expect(patched.id, 90);
      expect(patched.groupState!.pollVoteCounts, {0: 1});
      expect(patched.groupState!.myPollVoteOption, isNull);
      expect(original.groupState!.myPollVoteOption, 0);
      expect(adapter.request!.data, {'optionIndex': -1});
      expect(adapter.calls, 2);
    },
  );
  test('read endpoints require correct status and body shape', () async {
    adapter.body = {'lastReadChatMessageId': 90};
    await repository.markRead(ref, 90);
    expect(adapter.request!.uri.path, '/api/v1/travel-groups/7/messages/read');
    adapter.status = 204;
    adapter.body = null;
    await repository.markRead(
      const ChatThreadRef(kind: ChatKind.direct, id: 8),
      91,
    );
    expect(adapter.request!.uri.path, '/api/v1/direct-conversations/8/read');
  });
}

class _Adapter implements HttpClientAdapter {
  Object? body;
  int status = 200, calls = 0;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async =>
      key == 'access_token' ? 'test-token' : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
