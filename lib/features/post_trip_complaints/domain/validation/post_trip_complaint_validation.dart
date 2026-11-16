import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';

enum PostTripComplaintValidationMessage {
  requiredDetail,
  detailTooLong,
  unsupportedType,
  fileTooLarge,
  tooManyFiles,
  totalTooLarge,
  missingFileData,
}

abstract final class PostTripComplaintValidation {
  static const maxFiles = 5;
  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxTotalBytes = 30 * 1024 * 1024;
  static const _types = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  static PostTripComplaintValidationMessage? validateDetail(String value) {
    final text = value.trim();
    if (text.isEmpty) return PostTripComplaintValidationMessage.requiredDetail;
    if (text.length > 2000) {
      return PostTripComplaintValidationMessage.detailTooLong;
    }
    return null;
  }

  static PostTripComplaintValidationMessage? validateEvidence(
    List<SelectedEvidence> evidence, {
    int existingCount = 0,
    int existingBytes = 0,
    bool requireData = false,
  }) {
    if (existingCount + evidence.length > maxFiles) {
      return PostTripComplaintValidationMessage.tooManyFiles;
    }
    var total = existingBytes;
    for (final item in evidence) {
      if (!_types.contains(item.contentType.toLowerCase())) {
        return PostTripComplaintValidationMessage.unsupportedType;
      }
      if (item.sizeBytes <= 0 || item.sizeBytes > maxFileBytes) {
        return PostTripComplaintValidationMessage.fileTooLarge;
      }
      if (requireData && item.bytes == null) {
        return PostTripComplaintValidationMessage.missingFileData;
      }
      total += item.sizeBytes;
      if (total > maxTotalBytes) {
        return PostTripComplaintValidationMessage.totalTooLarge;
      }
    }
    return null;
  }
}
