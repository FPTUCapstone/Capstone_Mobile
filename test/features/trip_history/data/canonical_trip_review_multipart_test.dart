import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/canonical_trip_review_repository_impl.dart';

void main() {
  test('metadata is application/json without a multipart filename', () async {
    final form = buildCanonicalReviewMultipart(
      rating: 5,
      title: 'Great',
      content: 'Excellent trip',
      publishDisplayName: true,
      photos: const [],
    );
    final bytes = <int>[];
    await for (final chunk in form.finalize()) {
      bytes.addAll(chunk);
    }
    final body = utf8.decode(bytes);
    expect(body, contains('name="metadata"'));
    expect(body, contains('content-type: application/json'));
    expect(body, isNot(contains('name="metadata"; filename=')));
    expect(body, contains('"overallRating":5'));
  });
}
