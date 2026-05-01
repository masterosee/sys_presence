// lib/screens/qr/qr_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/attendance_service.dart' show AttendanceService;
import '../../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  final bool isCheckout;
  const QrScannerScreen({super.key, this.isCheckout = false});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final AttendanceService _service = AttendanceService();
  final MobileScannerController _controller = MobileScannerController();

  bool _processing = false;
  bool _done = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final raw = barcode!.rawValue!;
    if (!raw.startsWith('CONATEL:CHECKIN:')) return;

    final token = raw.replaceFirst('CONATEL:CHECKIN:', '');
    setState(() => _processing = true);
    _controller.stop();

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      if (widget.isCheckout) {
        final result = await _service.checkout(
          method: 'qr_code',
          qrToken: token,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
        setState(() {
          _done = true;
          _success = true;
          _message =
              '✅ Sortie enregistrée !\nVous avez travaillé ${result.workDurationFormatted}';
        });
      } else {
        final result = await _service.checkinQR(
          qrToken: token,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
        setState(() {
          _done = true;
          _success = true;
          _message = result.isLate
              ? '⚠️ Entrée enregistrée\nEn retard de ${result.lateMinutes} minutes'
              : '✅ Entrée enregistrée !\nBonne journée !';
        });
      }
    } catch (e) {
      setState(() {
        _done = true;
        _success = false;
        _message =
            '❌ Erreur : ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Caméra
          if (!_done)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

          // Overlay scanner
          if (!_done) _buildScannerOverlay(),

          // Résultat
          if (_done) _buildResult(),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.isCheckout ? 'Scanner — Sortie' : 'Scanner — Entrée',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: _ScannerOverlayShape(
          borderColor: AppColors.blue,
          borderRadius: 16,
          borderLength: 40,
          borderWidth: 4,
          cutOutSize: 260,
        ),
        color: Colors.black54,
      ),
      child: Align(
        alignment: const Alignment(0, 0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_processing)
              const CircularProgressIndicator(color: AppColors.blue)
            else
              Text(
                'Pointez vers le QR Code\naffiché au bureau',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: (_success ? AppColors.green : AppColors.red)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: _success ? AppColors.green : AppColors.red,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _message ?? '',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blue, AppColors.purple],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Retour à l\'accueil',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Overlay shape ───────────────────────────────────────────

class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const _ScannerOverlayShape({
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.borderLength,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final cutOut = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(cutOut, Radius.circular(borderRadius)));

    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
