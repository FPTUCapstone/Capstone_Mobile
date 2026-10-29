import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

class CheckInCameraScannerView extends StatefulWidget {
  const CheckInCameraScannerView({
    required this.onScanned,
    this.isPaused = false,
    this.scannerBuilder,
    super.key,
  });

  final ValueChanged<String> onScanned;
  final bool isPaused;
  final Widget Function(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  })? scannerBuilder;

  @override
  State<CheckInCameraScannerView> createState() => _CheckInCameraScannerViewState();
}

class _CheckInCameraScannerViewState extends State<CheckInCameraScannerView> {
  late final MobileScannerController _controller;
  DateTime? _lastScannedTime;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(String raw) {
    if (widget.isPaused) return;

    // Scan debouncing: ignore scans within 1.5 seconds of each other
    final now = DateTime.now();
    if (_lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(milliseconds: 1500)) {
      return;
    }

    _lastScannedTime = now;
    widget.onScanned(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF22304C), Color(0xFF101A2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.scannerBuilder != null)
            widget.scannerBuilder!(context, onDetect: _handleDetect)
          else
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    _handleDetect(raw);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) {
                return Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: const Text(
                    'Camera unavailable. Please use manual code entry.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

          // Reticle scan frame overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 220,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0E9F6E), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 0,
                        spreadRadius: 2000,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Green laser scan beam
          Positioned(
            left: 50,
            right: 50,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF0E9F6E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E9F6E).withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // Bottom helper hint text
          const Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Text(
              "Scan the traveler's e-ticket QR code",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
