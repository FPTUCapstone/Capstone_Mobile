import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dev_search_evidence.dart';

void main() {
  test('credential redaction is rechecked after removing controls', () {
    final response = Response<Object?>(
      requestOptions: RequestOptions(
        path: '/api/dev/tours/search',
        queryParameters: {'keyword': 'secret-\ntest-value'},
      ),
      statusCode: 200,
    );
    expect(
      (devSearchEvidence(response, credential: 'secret-test-value')['query']
          as Map)['keyword'],
      '[redacted]',
    );
  });
  test(
    'Kestrel colon trace is preserved while control or credential traces are omitted',
    () {
      for (final value in [
        '0HNABC123:00000001',
        'bad\ntrace',
        'secret-test-value',
      ]) {
        final response = Response<Object?>(
          requestOptions: RequestOptions(path: '/api/dev/tours/search'),
          statusCode: 200,
          headers: Headers.fromMap({
            'X-TM70-Trace-Id': [value],
          }),
        );
        expect(
          devSearchEvidence(
            response,
            credential: 'secret-test-value',
          )['traceId'],
          value == '0HNABC123:00000001' ? value : isNull,
        );
      }
    },
  );
  test(
    'category numeric identifiers are preserved without category bodies',
    () {
      final response = Response<Object?>(
        requestOptions: RequestOptions(path: '/api/dev/tours/categories'),
        statusCode: 200,
        data: [
          {'categoryId': 1, 'code': 'server-code', 'name': 'server-name'},
        ],
      );
      expect(devSearchEvidence(response, credential: 'test-key')['resultIds'], [
        '1',
      ]);
    },
  );
  test('control characters are removed before bounded substring', () {
    final response = Response<Object?>(
      requestOptions: RequestOptions(
        path: '/api/dev/tours/search',
        queryParameters: {'keyword': 'Hội\nAn'},
      ),
      statusCode: 200,
    );
    expect(
      (devSearchEvidence(response, credential: 'test-key')['query']
          as Map)['keyword'],
      'HộiAn',
    );
  });
  test(
    'evidence whitelists safe fields and redacts credential in any selected value',
    () {
      final response = Response<Object?>(
        requestOptions: RequestOptions(
          path: '/api/dev/tours/search',
          headers: {
            'X-TM70-Dev-Key': 'secret-test-value',
            'Authorization': 'Bearer hidden',
          },
          queryParameters: {
            'mode': 'hybrid',
            'keyword': 'secret-test-value',
            'page': 1,
            'token': 'hidden',
          },
        ),
        statusCode: 200,
        headers: Headers.fromMap({
          'X-TM70-Trace-Id': ['abc123'],
          'Set-Cookie': ['hidden'],
        }),
        data: {
          'totalCount': 4,
          'items': [
            {'tourId': '1', 'title': 'secret-test-value'},
          ],
          'connectionString': 'hidden',
          'detail': 'secret-test-value',
        },
      );
      final evidence = devSearchEvidence(
        response,
        credential: 'secret-test-value',
      );
      expect(evidence['path'], '/api/dev/tours/search');
      expect(evidence['status'], 200);
      expect(evidence['traceId'], 'abc123');
      expect(evidence['resultIds'], ['1']);
      expect(evidence['totalCount'], 4);
      expect(evidence['query'], {
        'mode': 'hybrid',
        'keyword': '[redacted]',
        'page': 1,
      });
      final encoded = jsonEncode(evidence);
      for (final forbidden in [
        'secret-test-value',
        'hidden',
        'Set-Cookie',
        'Authorization',
        'connectionString',
        'detail',
        'title',
      ]) {
        expect(encoded.contains(forbidden), isFalse);
      }
    },
  );
}
