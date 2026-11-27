import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_operator/data/datasources/operator_profile_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_operator/data/repositories/demo_operator_profile_repository.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';

typedef _StubHandler = Future<ResponseBody> Function(RequestOptions options);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _StubHandler _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _sampleProfileJson = <String, dynamic>{
  'userId': 12,
  'businessName': 'Sun Tours',
  'businessDescription': 'Family tours',
  'businessAddress': '1 Beach Rd',
  'contactPhone': '0901234567',
  'contactEmail': 'hello@suntours.vn',
  'website': 'https://suntours.vn',
  'logoUrl': 'https://res.cloudinary.com/demo/logo.png',
  'businessLicenceNumber': '79-1234/2026/TCDL-GPLHQT',
  'taxCode': '0312345678',
  'approvalStatus': 'Approved',
  'accountEmail': 'owner@suntours.vn',
};

void main() {
  group('DioOperatorProfileRemoteDataSource', () {
    test('getProfile parses GET /api/v1/operator/profile', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          expect(options.method, 'GET');
          expect(options.path, '/api/v1/operator/profile');
          return _jsonBody(_sampleProfileJson, 200);
        });
      final ds = DioOperatorProfileRemoteDataSource(dio);

      final profile = await ds.getProfile();
      expect(profile.userId, 12);
      expect(profile.businessName, 'Sun Tours');
      expect(profile.logoUrl, 'https://res.cloudinary.com/demo/logo.png');
    });

    test(
      'updateProfile sends all 6 trimmed text fields and removeLogo=true without logo',
      () async {
        FormData? capturedForm;
        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            expect(options.method, 'PUT');
            expect(options.path, '/api/v1/operator/profile');
            capturedForm = options.data as FormData;
            return _jsonBody({
              'code': 'operator_profile.updated',
              'profile': {
                ..._sampleProfileJson,
                'businessName': 'Sun Tours New',
                'logoUrl': null,
              },
            }, 200);
          });
        final ds = DioOperatorProfileRemoteDataSource(dio);

        final updated = await ds.updateProfile(
          const UpdateOperatorProfileInput(
            businessName: '  Sun Tours New  ',
            businessDescription: '  ',
            businessAddress: ' 1 Beach Rd ',
            contactPhone: ' 0901234567 ',
            contactEmail: ' hello@suntours.vn ',
            website: '',
            removeLogo: true,
          ),
        );

        expect(updated.businessName, 'Sun Tours New');
        expect(updated.logoUrl, isNull);
        final fieldMap = Map.fromEntries(capturedForm!.fields);
        expect(fieldMap['businessName'], 'Sun Tours New');
        expect(fieldMap['businessDescription'], '');
        expect(fieldMap['website'], '');
        expect(fieldMap['removeLogo'], 'true');
        expect(capturedForm!.files, isEmpty);
      },
    );

    test('falls back to GET when 200 PUT omits profile payload', () async {
      var callCount = 0;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          callCount += 1;
          if (options.method == 'PUT') {
            return _jsonBody({'code': 'operator_profile.updated'}, 200);
          }
          return _jsonBody(_sampleProfileJson, 200);
        });
      final ds = DioOperatorProfileRemoteDataSource(dio);

      final profile = await ds.updateProfile(
        const UpdateOperatorProfileInput(
          businessName: 'Sun Tours',
          businessDescription: '',
          businessAddress: '',
          contactPhone: '',
          contactEmail: '',
          website: '',
        ),
      );

      expect(callCount, 2);
      expect(profile.businessName, 'Sun Tours');
    });

    test('maps 400 ProblemDetails field errors including removeLogo', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((_) async {
          return _jsonBody({
            'status': 400,
            'errorCode': 'operator_profile.request_invalid',
            'errors': {
              'contactPhone': ['MSG04'],
              'removeLogo': ['operator_profile.request_invalid'],
            },
          }, 400);
        });
      final ds = DioOperatorProfileRemoteDataSource(dio);

      await expectLater(
        ds.updateProfile(
          const UpdateOperatorProfileInput(
            businessName: 'Sun Tours',
            businessDescription: '',
            businessAddress: '',
            contactPhone: '0901234567',
            contactEmail: '',
            website: '',
          ),
        ),
        throwsA(
          isA<OperatorProfileValidationException>()
              .having(
                (e) => e.errors.contactPhone,
                'contactPhone',
                contains('MSG04'),
              )
              .having((e) => e.errors.removeLogo, 'removeLogo', isNotNull),
        ),
      );
    });

    test('maps 413 and bare 400 without errors to MSG19 on logo', () async {
      for (final status in [413, 400]) {
        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter(
            (_) async => _jsonBody({'title': 'Too large'}, status),
          );
        final ds = DioOperatorProfileRemoteDataSource(dio);

        await expectLater(
          ds.updateProfile(
            const UpdateOperatorProfileInput(
              businessName: 'Sun Tours',
              businessDescription: '',
              businessAddress: '',
              contactPhone: '',
              contactEmail: '',
              website: '',
            ),
          ),
          throwsA(
            isA<OperatorProfileValidationException>().having(
              (e) => e.errors.logo,
              'logo',
              contains('MSG19'),
            ),
          ),
        );
      }
    });

    test(
      'maps 401, 403 (MSG126), and 503 (MSG127) to typed failure exceptions',
      () async {
        final cases = <(int, OperatorProfileFailureKind, String)>[
          (401, OperatorProfileFailureKind.unauthorized, 'Phiên đăng nhập'),
          (403, OperatorProfileFailureKind.forbidden, 'MSG126'),
          (503, OperatorProfileFailureKind.unavailable, 'MSG127'),
        ];

        for (final (status, kind, expectedText) in cases) {
          final dio = Dio()
            ..httpClientAdapter = _FakeAdapter(
              (_) async => _jsonBody({'errorCode': 'test'}, status),
            );
          final ds = DioOperatorProfileRemoteDataSource(dio);

          await expectLater(
            ds.getProfile(),
            throwsA(
              isA<OperatorProfileFailureException>()
                  .having((e) => e.kind, 'kind', kind)
                  .having((e) => e.message, 'message', contains(expectedText)),
            ),
          );
        }
      },
    );
  });

  group('DemoOperatorProfileRepository', () {
    test('persists edits in-memory during session', () async {
      final repo = DemoOperatorProfileRepository();
      final initial = await repo.getProfile();
      expect(initial.isDemo, isTrue);

      await repo.updateProfile(
        const UpdateOperatorProfileInput(
          businessName: 'Demo Updated Co',
          businessDescription: 'Updated',
          businessAddress: '',
          contactPhone: '0901234567',
          contactEmail: 'demo@example.vn',
          website: 'https://demo.vn',
          removeLogo: true,
        ),
      );

      final reloaded = await repo.getProfile();
      expect(reloaded.businessName, 'Demo Updated Co');
      expect(reloaded.logoUrl, isNull);
    });
  });
}
