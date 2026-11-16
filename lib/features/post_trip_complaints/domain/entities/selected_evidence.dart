import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Transient picker data. It is never persisted or included in complaint state
/// after a successful request.
final class SelectedEvidence extends Equatable {
  const SelectedEvidence({
    required this.name,
    required this.sizeBytes,
    required this.contentType,
    this.bytes,
  });

  final String name;
  final int sizeBytes;
  final String contentType;
  final Uint8List? bytes;

  @override
  List<Object?> get props => [name, sizeBytes, contentType];
}
