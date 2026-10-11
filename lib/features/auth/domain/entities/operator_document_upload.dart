import 'dart:typed_data';

final class OperatorDocumentUpload {
  const OperatorDocumentUpload({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;
}
