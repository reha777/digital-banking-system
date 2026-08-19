import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/app_theme.dart';
import '../../../widgets/mobile_shell.dart';

class ScanReceiveQrPage extends StatefulWidget {
  const ScanReceiveQrPage({super.key});

  @override
  State<ScanReceiveQrPage> createState() => _ScanReceiveQrPageState();
}

class _ScanReceiveQrPageState extends State<ScanReceiveQrPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  void _detected(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null || value.isEmpty) return;
    _handled = true;
    _controller.stop();
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (context, error) => _ScannerError(
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Camera permission is required to scan a QR code.'
                  : 'The camera could not be started.',
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 12,
            child: Row(
              children: [
                CircleIconButton(
                  icon: LucideIcons.arrowLeft,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                const Expanded(
                  child: Text(
                    'Scan QR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Positioned(
            left: 28,
            right: 28,
            bottom: 46,
            child: Text(
              'Place a Receive Money QR code inside the frame.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleAlert, color: Colors.white, size: 42),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}
