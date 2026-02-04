import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerUtil {
  static Future<String?> scanQRCode(BuildContext context) async {
    return await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: MobileScannerController(
                facing: CameraFacing.back,
                torchEnabled: false,
              ),
              onDetect: (BarcodeCapture capture) {
                final barcode = capture.barcodes.first;
                final String? code = barcode.rawValue;
                if (!_isScanned && code != null) {
                  _isScanned = true;
                  Navigator.pop(context, code);
                }
              },
            
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
            
              child: const Center(
                child: Text(
                  'Position the QR code within the frame',
                  style: TextStyle(
            
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  const ScannerOverlay({
    super.key,
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(
        borderColor: borderColor,
        borderRadius: borderRadius,
        borderLength: borderLength,
        borderWidth: borderWidth,
        cutOutSize: cutOutSize,
      ),
      child: Container(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final double left = (size.width - cutOutSize) / 2;
    final double top = (size.height - cutOutSize) / 2;
    final Rect cutOutRect = Rect.fromLTWH(left, top, cutOutSize, cutOutSize);
    final RRect borderRect = RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius));
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
