import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_state.dart';

void main() {
  group('TravelGroupRepositoryImpl invitation requests', () {
    late DioClient dioClient;
    late _RecordingHttpClientAdapter adapter;
    late TravelGroupRepositoryImpl repository;

    setUp(() {
      dioClient = _createDioClient();
      adapter = _RecordingHttpClientAdapter(body: _invitationResponse);
      dioClient.dio.httpClientAdapter = adapter;
      repository = TravelGroupRepositoryImpl(dioClient: dioClient);
    });

    test(
      'get-or-create posts the exact contract and parses the raw DTO',
      () async {
        const key = 'a4e3682e-0bbd-4722-a2ad-08f5c7fc8b16';

        final invitation = await repository.getOrCreateGroupInvitation(
          groupId: 42,
          idempotencyKey: key,
        );

        final request = adapter.request;
        expect(request?.method, 'POST');
        expect(request?.path, '/api/v1/travel-groups/42/invitation');
        expect(request?.headers['Idempotency-Key'], key);
        expect(request?.data, isNull);
        expect(invitation.groupId, 42);
        expect(invitation.groupName, 'Da Nang Summer Trip');
        expect(invitation.inviteCode, 'TM7X9K2A');
        expect(invitation.qrData, 'tripmate://groups/join?code=TM7X9K2A');
        expect(invitation.expiresAt, DateTime.utc(2026, 10, 14, 10, 30));
      },
    );

    test(
      'regenerate posts the exact contract without a request body',
      () async {
        const key = '31f68011-9af6-4aee-a7c2-9d4cf2ceffb0';

        await repository.regenerateGroupInvitation(
          groupId: 42,
          idempotencyKey: key,
        );

        final request = adapter.request;
        expect(request?.method, 'POST');
        expect(request?.path, '/api/v1/travel-groups/42/invitation/regenerate');
        expect(request?.headers['Idempotency-Key'], key);
        expect(request?.data, isNull);
      },
    );

    test(
      'maps an invitation permission response to PermissionFailure',
      () async {
        adapter = _RecordingHttpClientAdapter(
          statusCode: 403,
          body:
              '{"title":"Only the Group Host can manage invitations.",'
              '"status":403,'
              '"errorCode":"travel_group.host_permission_required"}',
        );
        dioClient.dio.httpClientAdapter = adapter;

        await expectLater(
          repository.getOrCreateGroupInvitation(
            groupId: 42,
            idempotencyKey: 'eb136613-f895-4a32-9e27-2c853fb9e54a',
          ),
          throwsA(isA<PermissionFailure>()),
        );
      },
    );

    test('maps an invitation authentication response safely', () async {
      adapter = _RecordingHttpClientAdapter(
        statusCode: 401,
        body: '{"detail":"internal authentication diagnostics"}',
      );
      dioClient.dio.httpClientAdapter = adapter;

      await expectLater(
        repository.regenerateGroupInvitation(
          groupId: 42,
          idempotencyKey: '5bd0b20e-08ce-4fc5-8f40-99f89ae172cf',
        ),
        throwsA(
          isA<AuthenticationFailure>().having(
            (failure) => failure.message,
            'safe message',
            'Please sign in to continue.',
          ),
        ),
      );
    });

    test('404 after an uncertain regeneration exits reconciliation', () async {
      final cubit = InviteGroupMembersCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.loadInvitation(42);

      final networkAdapter = _NetworkFailureHttpClientAdapter();
      dioClient.dio.httpClientAdapter = networkAdapter;
      await cubit.regenerateInvitation(42);
      expect(
        cubit.state.status,
        InviteGroupMembersStatus.regenerationUncertain,
      );

      final notFoundAdapter = _RecordingHttpClientAdapter(
        statusCode: 404,
        body:
            '{"title":"Travel group was not found.",'
            '"status":404,'
            '"errorCode":"travel_group.group_not_found"}',
      );
      dioClient.dio.httpClientAdapter = notFoundAdapter;
      await cubit.regenerateInvitation(42);

      expect(cubit.state.status, InviteGroupMembersStatus.failure);
      expect(cubit.state.invitation, isNull);
      expect(
        notFoundAdapter.request?.headers['Idempotency-Key'],
        networkAdapter.request?.headers['Idempotency-Key'],
      );
    });
  });

  group('TravelGroupRepositoryImpl existing operations', () {
    test(
      'create still posts its request and parses the raw group DTO',
      () async {
        final dioClient = _createDioClient();
        final adapter = _RecordingHttpClientAdapter(
          body:
              '{"groupId":7,"groupName":"Hue Weekend",'
              '"itineraryId":13,"hostUserId":9,'
              '"createdAtUtc":"2026-09-21T08:00:00Z"}',
        );
        dioClient.dio.httpClientAdapter = adapter;
        final repository = TravelGroupRepositoryImpl(dioClient: dioClient);

        final group = await repository.createTravelGroup(
          name: 'Hue Weekend',
          itineraryId: 13,
        );

        expect(adapter.request?.method, 'POST');
        expect(adapter.request?.path, '/api/v1/travel-groups');
        expect(adapter.request?.data, {
          'groupName': 'Hue Weekend',
          'itineraryId': 13,
        });
        expect(group.id, 7);
        expect(group.name, 'Hue Weekend');
        expect(group.itineraryId, 13);
      },
    );

    test('join still posts the normalized code and idempotency key', () async {
      const key = '8b69dd04-dd8d-46d3-8aa8-14565fabfd6b';
      final dioClient = _createDioClient();
      final adapter = _RecordingHttpClientAdapter(
        body:
            '{"groupId":8,"groupName":"Hoi An Friends",'
            '"itineraryId":21}',
      );
      dioClient.dio.httpClientAdapter = adapter;
      final repository = TravelGroupRepositoryImpl(dioClient: dioClient);

      final group = await repository.joinTravelGroup(
        invitationCode: ' tm7x9k2a ',
        idempotencyKey: key,
      );

      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.path, '/api/v1/travel-groups/join');
      expect(adapter.request?.headers['Idempotency-Key'], key);
      expect(adapter.request?.data, {'invitationCode': 'TM7X9K2A'});
      expect(group.id, 8);
      expect(group.name, 'Hoi An Friends');
      expect(group.itineraryId, 21);
    });
  });
}

const _invitationResponse =
    '{"groupId":42,"groupName":"Da Nang Summer Trip",'
    '"inviteCode":"TM7X9K2A",'
    '"qrData":"tripmate://groups/join?code=TM7X9K2A",'
    '"expiresAt":"2026-10-14T10:30:00Z"}';

DioClient _createDioClient() => DioClient(
  config: AppConfig(
    environment: Environment.production,
    apiBaseUrl: Uri.parse('https://api.test.invalid'),
  ),
  secureStorage: const _EmptySecureStorageService(),
);

final class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter({required this.body, this.statusCode = 200});

  final String body;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _NetworkFailureHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Connection interrupted after request transmission.',
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _EmptySecureStorageService implements SecureStorageService {
  const _EmptySecureStorageService();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
