import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

/// The ticket QR (UC-29 M1): [content] is the server's `qr.content`, encoded
/// exactly as received on a white quiet zone so it scans from a phone screen.
class ETicketQrCode extends StatelessWidget {
  const ETicketQrCode({
    required this.content,
    required this.size,
    required this.semanticsLabel,
    super.key,
  });

  final String content;
  final double size;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: QrImageView(
        data: content,
        size: size,
        backgroundColor: Colors.white,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
