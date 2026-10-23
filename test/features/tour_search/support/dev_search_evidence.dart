import 'package:dio/dio.dart';

/// Test-only whitelist. Never return arbitrary headers, bodies or exceptions.
Map<String, Object?> devSearchEvidence(
  Response<Object?> response, {
  required String credential,
}) {
  const canonicalKeys = {
    'keyword',
    'destination',
    'startDate',
    'endDate',
    'minPrice',
    'maxPrice',
    'durationDays',
    'category',
    'minimumRating',
    'sort',
    'page',
    'pageSize',
    'mode',
  };
  Object? safeValue(Object? value) {
    if (value is num && value.isFinite) return value;
    if (value is! String) return null;
    if (credential.isNotEmpty && value.contains(credential)) {
      return '[redacted]';
    }
    final normalized = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
    if (credential.isNotEmpty && normalized.contains(credential)) {
      return '[redacted]';
    }
    return normalized.substring(
      0,
      normalized.length > 500 ? 500 : normalized.length,
    );
  }

  String? safeIdentifier(Object? value) {
    if (value is int) value = value.toString();
    if (value is! String ||
        value.length > 96 ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value) ||
        (credential.isNotEmpty && value.contains(credential))) {
      return null;
    }
    return value;
  }

  String? safeTrace(Object? value) {
    if (value is! String ||
        value.length > 256 ||
        !RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value) ||
        (credential.isNotEmpty && value.contains(credential))) {
      return null;
    }
    return value;
  }

  final body = response.data;
  final page = body is Map ? body : null;
  final rows = body is List ? body : page?['items'];
  final ids = rows is List
      ? rows
            .whereType<Map>()
            .map((row) => safeIdentifier(row['tourId'] ?? row['categoryId']))
            .whereType<String>()
            .toList()
      : <String>[];
  final path = response.requestOptions.path;
  return {
    'path':
        const {
          '/api/dev/tours/search',
          '/api/dev/tours/categories',
        }.contains(path)
        ? path
        : '[unapproved-path]',
    'query': {
      for (final entry in response.requestOptions.queryParameters.entries)
        if (canonicalKeys.contains(entry.key) && safeValue(entry.value) != null)
          entry.key: safeValue(entry.value),
    },
    'status': response.statusCode,
    'traceId': safeTrace(response.headers.value('X-TM70-Trace-Id')),
    'resultIds': ids,
    'resultCount': rows is List ? rows.length : null,
    'totalCount': page?['totalCount'] is num ? page!['totalCount'] : null,
    'errorCode': safeIdentifier(page?['errorCode']),
  };
}
