import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';

abstract interface class PostTripComplaintRemoteDataSource {
  Future<PostTripComplaintContext> getContext(int bookingId);
  Future<PostTripComplaintSubmission> submit({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  });
  Future<PostTripComplaintEvidenceAmendment> amendEvidence({
    required int bookingId,
    required String idempotencyKey,
    required List<SelectedEvidence> evidence,
  });
  Future<List<MyPostTripComplaint>> listMine();
  Future<ComplaintEvidenceDownload> downloadEvidence({
    required int bookingId,
    required int evidenceId,
  });
}

final class DioPostTripComplaintRemoteDataSource
    implements PostTripComplaintRemoteDataSource {
  DioPostTripComplaintRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;
  static const _root = '/api/v1/traveler/bookings';

  @override
  Future<PostTripComplaintContext> getContext(int bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_root/${_positive(bookingId)}/post-trip-complaint',
    );
    final raw = _body(response.data);
    final id = _int(raw['bookingId']);
    final end = _date(raw['endAtUtc']);
    final deadline = _date(raw['submissionDeadlineUtc']);
    if (id == null ||
        end == null ||
        deadline == null ||
        raw['canSubmit'] is! bool ||
        raw['canAmendEvidence'] is! bool) {
      throw const FormatException('Complaint context is invalid.');
    }
    return PostTripComplaintContext(
      bookingId: id,
      bookingCode: _text(raw['bookingCode']),
      tourTitle: _text(raw['tourTitle']),
      endAtUtc: end,
      submissionDeadlineUtc: deadline,
      canSubmit: raw['canSubmit'] as bool,
      canAmendEvidence: raw['canAmendEvidence'] as bool,
      ineligibilityReason: _text(raw['ineligibilityReason']),
      complaint: raw['complaint'] == null
          ? null
          : _complaint(_map(raw['complaint'])),
    );
  }

  @override
  Future<PostTripComplaintSubmission> submit({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  }) async => _submission(
    await _post(
      bookingId: bookingId,
      path: 'post-trip-complaints',
      idempotencyKey: idempotencyKey,
      category: category,
      detail: detail,
      evidence: evidence,
    ),
  );

  @override
  Future<PostTripComplaintEvidenceAmendment> amendEvidence({
    required int bookingId,
    required String idempotencyKey,
    required List<SelectedEvidence> evidence,
  }) async => _amendment(
    await _post(
      bookingId: bookingId,
      path: 'post-trip-complaint/evidence',
      idempotencyKey: idempotencyKey,
      evidence: evidence,
    ),
  );

  Future<Map<String, dynamic>> _post({
    required int bookingId,
    required String path,
    required String idempotencyKey,
    PostTripComplaintReasonCategory? category,
    String? detail,
    required List<SelectedEvidence> evidence,
  }) async {
    final form = FormData();
    if (category != null) {
      form.fields.add(MapEntry('reasonCategory', category.wireValue));
    }
    if (detail != null) form.fields.add(MapEntry('reasonDetail', detail));
    for (final item in evidence) {
      final bytes = item.bytes;
      if (bytes == null) {
        throw const FormatException('Evidence bytes are unavailable.');
      }
      form.files.add(
        MapEntry(
          'evidence',
          MultipartFile.fromBytes(
            bytes,
            filename: item.name,
            contentType: DioMediaType.parse(item.contentType),
          ),
        ),
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '$_root/${_positive(bookingId)}/$path',
      data: form,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return _body(response.data);
  }

  @override
  Future<List<MyPostTripComplaint>> listMine() async {
    final response = await _dio.get<Object?>(
      '/api/v1/traveler/post-trip-complaints',
    );
    final raw = response.data is Map
        ? (response.data as Map)['data'] ?? response.data
        : response.data;
    if (raw is! List) throw const FormatException('Complaint list is invalid.');
    return raw
        .map((item) {
          final map = _map(item);
          final id = _int(map['complaintId']);
          final bookingId = _int(map['bookingId']);
          final category = PostTripComplaintReasonCategory.tryFromWire(
            map['reasonCategory']?.toString(),
          );
          final submitted = _date(map['submittedAtUtc']);
          final deadline = _date(map['responseDeadlineUtc']);
          final bookingCode = _text(map['bookingCode']);
          final title = _text(map['tourTitle']);
          final status = _text(map['status']);
          final count = _int(map['evidenceCount']);
          if (id == null ||
              bookingId == null ||
              category == null ||
              submitted == null ||
              deadline == null ||
              bookingCode == null ||
              title == null ||
              status == null ||
              count == null) {
            throw const FormatException('Complaint list item is invalid.');
          }
          return MyPostTripComplaint(
            complaintId: id,
            bookingId: bookingId,
            bookingCode: bookingCode,
            tourTitle: title,
            status: status,
            reasonCategory: category,
            submittedAtUtc: submitted,
            responseDeadlineUtc: deadline,
            evidenceCount: count,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ComplaintEvidenceDownload> downloadEvidence({
    required int bookingId,
    required int evidenceId,
  }) async {
    final response = await _dio.get<List<int>>(
      '$_root/${_positive(bookingId)}/post-trip-complaint/evidence/${_positive(evidenceId)}/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Evidence download is empty.');
    }
    final disposition = response.headers.value('content-disposition') ?? '';
    final name =
        RegExp(r'filename="?([^";]+)').firstMatch(disposition)?.group(1) ??
        'evidence-$evidenceId';
    return ComplaintEvidenceDownload(
      bytes: Uint8List.fromList(bytes),
      fileName: name,
      contentType:
          response.headers.value('content-type') ?? 'application/octet-stream',
    );
  }

  static ExistingPostTripComplaint _complaint(Map<String, dynamic> raw) {
    final id = _int(raw['complaintId']);
    final category = PostTripComplaintReasonCategory.tryFromWire(
      raw['reasonCategory']?.toString(),
    );
    final detail = _text(raw['reasonDetail']);
    final status = _text(raw['status']);
    final submitted = _date(raw['submittedAtUtc']);
    final deadline = _date(raw['responseDeadlineUtc']);
    final items = raw['evidence'];
    if (id == null ||
        category == null ||
        detail == null ||
        status == null ||
        submitted == null ||
        deadline == null ||
        items is! List) {
      throw const FormatException('Existing complaint is invalid.');
    }
    final evidence = items
        .map((item) {
          final map = _map(item);
          final evidenceId = _int(map['evidenceId']);
          final fileName = _text(map['fileName']);
          final type = _text(map['contentType']);
          final size = _int(map['sizeBytes']);
          if (evidenceId == null ||
              fileName == null ||
              type == null ||
              size == null) {
            throw const FormatException('Evidence is invalid.');
          }
          return ComplaintEvidence(
            id: evidenceId,
            fileName: fileName,
            contentType: type,
            sizeBytes: size,
          );
        })
        .toList(growable: false);
    return ExistingPostTripComplaint(
      id: id,
      status: status,
      reasonCategory: category,
      reasonDetail: detail,
      submittedAtUtc: submitted,
      responseDeadlineUtc: deadline,
      evidence: evidence,
    );
  }

  static PostTripComplaintSubmission _submission(Map<String, dynamic> raw) {
    final id = _int(raw['complaintId']);
    final bookingId = _int(raw['bookingId']);
    final status = _text(raw['status']);
    final submitted = _date(raw['submittedAtUtc']);
    final deadline = _date(raw['responseDeadlineUtc']);
    final replay = raw['isReplay'];
    if (id == null ||
        bookingId == null ||
        status == null ||
        submitted == null ||
        deadline == null ||
        replay is! bool) {
      throw const FormatException('Complaint submission is invalid.');
    }
    return PostTripComplaintSubmission(
      complaintId: id,
      bookingId: bookingId,
      status: status,
      submittedAtUtc: submitted,
      responseDeadlineUtc: deadline,
      isReplay: replay,
    );
  }

  static PostTripComplaintEvidenceAmendment _amendment(
    Map<String, dynamic> raw,
  ) {
    final id = _int(raw['complaintId']);
    final usedAt = _date(raw['evidenceAmendmentUsedAtUtc']);
    final count = _int(raw['evidenceCount']);
    final totalBytes = _int(raw['evidenceTotalBytes']);
    final replay = raw['isReplay'];
    if (id == null ||
        usedAt == null ||
        count == null ||
        totalBytes == null ||
        replay is! bool) {
      throw const FormatException('Evidence amendment response is invalid.');
    }
    return PostTripComplaintEvidenceAmendment(
      complaintId: id,
      evidenceAmendmentUsedAtUtc: usedAt,
      evidenceCount: count,
      evidenceTotalBytes: totalBytes,
      isReplay: replay,
    );
  }

  static Map<String, dynamic> _body(Map<String, dynamic>? body) {
    final raw = body?['data'] is Map<String, dynamic> ? body!['data'] : body;
    return _map(raw);
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic>
      ? value
      : throw const FormatException('Response is invalid.');
  static int _positive(int value) {
    if (value <= 0) throw const FormatException('Identifier is invalid.');
    return value;
  }

  static int? _int(Object? value) => switch (value) {
    int item => item,
    num item => item.toInt(),
    String item => int.tryParse(item),
    _ => null,
  };
  static String? _text(Object? value) {
    final item = value?.toString().trim();
    return item == null || item.isEmpty ? null : item;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
