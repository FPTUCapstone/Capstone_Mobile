import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';

abstract interface class OperatorDocumentPicker {
  /// Null means the user cancelled the platform picker.
  Future<List<OperatorDocumentUpload>?> pick({required bool multiple});
}

final class FilePickerOperatorDocumentPicker implements OperatorDocumentPicker {
  const FilePickerOperatorDocumentPicker();

  @override
  Future<List<OperatorDocumentUpload>?> pick({required bool multiple}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: multiple,
      withReadStream: true,
    );
    if (result == null) return null;
    if (result.files.length > (multiple ? 5 : 1)) {
      throw const OperatorDocumentReadFailure();
    }
    final documents = <OperatorDocumentUpload>[];
    for (final file in result.files) {
      if (file.size <= 0 || file.size > 5 * 1024 * 1024) {
        throw const OperatorDocumentReadFailure();
      }
      final extension = file.extension?.toLowerCase();
      final mime = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };
      final stream = file.readStream;
      if (stream == null || mime == 'application/octet-stream') {
        throw const OperatorDocumentReadFailure();
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        if (builder.length + chunk.length > 5 * 1024 * 1024) {
          throw const OperatorDocumentReadFailure();
        }
        builder.add(chunk);
      }
      documents.add(
        OperatorDocumentUpload(
          fileName: file.name,
          contentType: mime,
          bytes: builder.takeBytes(),
        ),
      );
    }
    return documents;
  }
}

final class OperatorDocumentReadFailure implements Exception {
  const OperatorDocumentReadFailure();
}
