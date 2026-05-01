/// Écran principal employé - Tableau de bord
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _todayAttendance;
  bool _loading = true;
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiServiceProvider);
    final name = await api.getFullName();
    final attendance = await api.getTodayAttendance();
    if (mounted) {
      setState(() {
        _fullName = name;
        _todayAttendance = attendance;
        _loading = false;
      });
    }
  }

  bool get _hasCheckedIn =>
      _todayAttendance != null && _todayAttendance!['check_in'] != null;

  bool get _hasCheckedOut =>
      _todayAttendance != null && _todayAttendance!['check_out'] != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStatusCard(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildTodaySummary(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── En-tête ────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bon matin'
        : now.hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTheme.textSecondary),
              const SizedBox(height: 4),
              Text(
                _fullName ?? 'Employé',
                style: AppTheme.heading1,
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.person_outline, color: AppTheme.primary),
        ),
      ],
    );
  }

  // ─── Carte statut du jour ────────────────────────────
  Widget _buildStatusCard() {
    final status = _todayAttendance?['status'] ?? 'not_checked_in';
    final isLate = _todayAttendance?['is_late'] ?? false;

    Color cardColor;
    String statusText;
    IconData statusIcon;

    if (!_hasCheckedIn) {
      cardColor = AppTheme.warning;
      statusText = 'Pas encore pointé';
      statusIcon = Icons.schedule_outlined;
    } else if (_hasCheckedOut) {
      cardColor = AppTheme.success;
      statusText = 'Journée terminée';
      statusIcon = Icons.check_circle_outline;
    } else if (isLate) {
      cardColor = AppTheme.error;
      statusText = 'En retard · ${_todayAttendance!['late_minutes']} min';
      statusIcon = Icons.warning_amber_outlined;
    } else {
      cardColor = AppTheme.success;
      statusText = 'En service';
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(statusText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTimeBox('Entrée', _todayAttendance?['check_in']),
              const SizedBox(width: 16),
              _buildTimeBox('Sortie', _todayAttendance?['check_out']),
              const Spacer(),
              if (_hasCheckedIn && !_hasCheckedOut) _buildLiveTimer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, String? isoTime) {
    String timeStr = '--:--';
    if (isoTime != null) {
      final dt = DateTime.parse(isoTime).toLocal();
      timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(timeStr,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildLiveTimer() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        if (_todayAttendance?['check_in'] == null) return const SizedBox();
        final checkIn = DateTime.parse(_todayAttendance!['check_in']).toLocal();
        final diff = DateTime.now().difference(checkIn);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${h}h ${m.toString().padLeft(2, '0')}m',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        );
      },
    );
  }

  // ─── Boutons d'action ────────────────────────────────
  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!_hasCheckedIn) ...[
          _ActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Scanner QR Code',
            subtitle: 'Pointage au bureau',
            color: AppTheme.primary,
            onTap: _scanQRCode,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.location_on_outlined,
            label: 'Pointer ma présence',
            subtitle: 'Via GPS · À distance',
            color: AppTheme.secondary,
            onTap: _checkinGPS,
          ),
        ] else if (!_hasCheckedOut) ...[
          _ActionButton(
            icon: Icons.logout,
            label: 'Pointer ma sortie',
            subtitle: 'Enregistrer la fin de journée',
            color: AppTheme.error,
            onTap: _checkout,
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('Journée complète enregistrée',
                    style: TextStyle(
                        color: AppTheme.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Résumé du jour ──────────────────────────────────
  Widget _buildTodaySummary() {
    final duration = _todayAttendance?['work_duration'];
    final method = _todayAttendance?['check_in_method'] ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Résumé d'aujourd'hui", style: AppTheme.heading2),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                icon: Icons.timer_outlined,
                label: 'Heures travaillées',
                value: duration != null
                    ? '${duration ~/ 60}h${(duration % 60).toString().padLeft(2, '0')}'
                    : '--',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryTile(
                icon: Icons.fingerprint,
                label: 'Méthode pointage',
                value: _formatMethod(method),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatMethod(String? method) {
    switch (method) {
      case 'qr_code': return 'QR Code';
      case 'gps': return 'GPS';
      case 'pin': return 'PIN';
      case 'nfc': return 'NFC';
      case 'biometric': return 'Biométrie';
      default: return '--';
    }
  }

  // ─── Actions ─────────────────────────────────────────
  Future<void> _scanQRCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result != null && mounted) {
      await _doCheckinQR(result);
    }
  }

  Future<void> _doCheckinQR(String token) async {
    try {
      _showLoading('Enregistrement...');
      final api = ref.read(apiServiceProvider);

      // Obtenir GPS en parallèle
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      final attendance = await api.checkinQR(
        qrToken: token,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (mounted) Navigator.of(context).pop(); // Fermer loading
      _showSuccess(attendance.message);
      await _loadData();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showError(e.toString());
    }
  }

  Future<void> _checkinGPS() async {
    try {
      // Vérifier permission GPS
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _showError('Permission GPS refusée');
          return;
        }
      }

      _showLoading('Localisation en cours...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) Navigator.of(context).pop();
      _showLoading('Enregistrement...');

      final api = ref.read(apiServiceProvider);
      final attendance = await api.checkinGPS(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (mounted) Navigator.of(context).pop();
      _showSuccess(attendance.message);
      await _loadData();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showError(e.toString());
    }
  }

  Future<void> _checkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pointer la sortie ?'),
        content: const Text('Confirmez-vous la fin de votre journée de travail ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      _showLoading('Enregistrement sortie...');
      final api = ref.read(apiServiceProvider);

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      final attendance = await api.checkout(
        method: 'gps',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (mounted) Navigator.of(context).pop();
      _showSuccess(attendance.message);
      await _loadData();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showError(e.toString());
    }
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message.replaceAll('Exception: ', '')),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ─── Widget bouton action ───────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: color)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Widget tuile résumé ────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

// ─── Écran scanner QR ───────────────────────────────────
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scanner le QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.first;
              final raw = barcode.rawValue ?? '';
              if (raw.startsWith('CONATEL:CHECKIN:')) {
                setState(() => _scanned = true);
                final token = raw.replaceFirst('CONATEL:CHECKIN:', '');
                Navigator.of(context).pop(token);
              }
            },
          ),
          // Cadre de visée
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: const Text(
              'Pointez la caméra vers le QR Code\naffiché à l\'entrée du bureau',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
