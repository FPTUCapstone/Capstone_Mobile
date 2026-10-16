import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';

const tourImageMaxBytes = 5 * 1024 * 1024;

abstract interface class TourImagePicker {
  /// Null means the operator cancelled. Throws [TourImageReadFailure] for an unreadable,
  /// unsupported or oversized file (BR-16: images up to 5 MB).
  Future<TourImageUpload?> pickImage();
}

final class FilePickerTourImagePicker implements TourImagePicker {
  const FilePickerTourImagePicker();

  @override
  Future<TourImageUpload?> pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size <= 0 || file.size > tourImageMaxBytes) {
      throw const TourImageReadFailure();
    }
    final mime = switch (file.extension?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
    final stream = file.readStream;
    if (mime == null || stream == null) throw const TourImageReadFailure();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > tourImageMaxBytes) {
        throw const TourImageReadFailure();
      }
      builder.add(chunk);
    }
    return TourImageUpload(
      fileName: file.name,
      contentType: mime,
      bytes: builder.takeBytes(),
    );
  }
}

final class TourImageReadFailure implements Exception {
  const TourImageReadFailure();
}
