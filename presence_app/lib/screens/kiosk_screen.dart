/// Écran Kiosque - Tablette à l'entrée du bureau
/// Affiche un QR Code dynamique qui se renouvelle toutes les 30 secondes
/// Les employés scannent ce QR avec leur téléphone pour pointer

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen>
    with TickerProviderStateMixin {

  // QR Data
  Map<String, dynamic>? _qrData;
  bool _loading = true;
  String? _error;
  String? _selectedGeofenceId;
  List<dynamic> _geofences = [];

  // Compte à rebours
  int _secondsLeft = 30;
  Timer? _countdownTimer;
  Timer? _refreshTimer;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Heure en direct
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _loadGeofences();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _clockTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Charger les zones géographiques ──────────────────
  Future<void> _loadGeofences() async {
    try {
      final api = ref.read(apiServiceProvider);
      final geofences = await api.getGeofences();
      if (mounted) {
        setState(() {
          _geofences = geofences;
          if (geofences.isNotEmpty) {
            _selectedGeofenceId = geofences[0]['id'];
          }
        });
        _startQRCycle();
      }
    } catch (e) {
      setState(() {
        _error = 'Impossible de se connecter au serveur.\nVérifiez la connexion réseau.';
        _loading = false;
      });
    }
  }

  // ─── Cycle QR : génère + compte à rebours ─────────────
  void _startQRCycle() {
    _generateQR();
    // Renouveler toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _generateQR();
    });
  }

  Future<void> _generateQR() async {
    if (_selectedGeofenceId == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.generateQR(_selectedGeofenceId!);
      if (mounted) {
        setState(() {
          _qrData = data;
          _secondsLeft = 30;
          _loading = false;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de génération du QR Code';
          _loading = false;
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // ─── Build principal ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fond sombre professionnel
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _error != null
                  ? _buildError()
                  : _geofences.isEmpty && !_loading
                      ? _buildNoGeofence()
                      : _buildQRSection(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─── Barre supérieure : heure + zone ──────────────────
  Widget _buildTopBar() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    final months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    final dayName = days[_now.weekday - 1];
    final dateStr = '$dayName ${_now.day} ${months[_now.month - 1]} ${_now.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fingerprint, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('CONATEL',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 18, letterSpacing: 2)),
            ],
          ),

          const Spacer(),

          // Zone sélectionnée
          if (_geofences.isNotEmpty)
            DropdownButton<String>(
              value: _selectedGeofenceId,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              items: _geofences.map<DropdownMenuItem<String>>((g) {
                return DropdownMenuItem(
                  value: g['id'].toString(),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(g['name'].toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedGeofenceId) {
                  setState(() => _selectedGeofenceId = val);
                  _refreshTimer?.cancel();
                  _startQRCycle();
                }
              },
            ),

          const Spacer(),

          // Horloge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$h:$m:$s',
                  style: const TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.bold, letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()])),
              Text(dateStr,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section QR principale ────────────────────────────
  Widget _buildQRSection() {
    return Row(
      children: [
        // Côté gauche : instructions
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pointez votre\nprésence',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    )),
                const SizedBox(height: 16),
                Text('Scannez le QR Code avec l\'application\nCONATEL sur votre téléphone',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, height: 1.5)),
                const SizedBox(height: 48),
                _buildStep(1, Icons.phone_android_outlined, 'Ouvrez l\'app CONATEL'),
                const SizedBox(height: 20),
                _buildStep(2, Icons.qr_code_scanner, 'Appuyez sur "Scanner QR Code"'),
                const SizedBox(height: 20),
                _buildStep(3, Icons.check_circle_outline, 'Votre présence est enregistrée !'),
              ],
            ),
          ),
        ),

        // Côté droit : QR Code
        Expanded(
          flex: 3,
          child: Center(
            child: _loading
                ? _buildLoadingQR()
                : _buildQRCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int num, IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Center(
            child: Text('$num',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 14),
        Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15)),
      ],
    );
  }

  Widget _buildLoadingQR() {
    return Container(
      width: 300, height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Génération du QR...', style: TextStyle(color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildQRCard() {
    final qrBase64 = _qrData?['qr_image_base64'] as String?;
    final isExpiringSoon = _secondsLeft <= 5;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cadre QR
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isExpiringSoon ? AppTheme.error : AppTheme.primary)
                      .withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: qrBase64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(qrBase64),
                      width: 260,
                      height: 260,
                      fit: BoxFit.contain,
                    ),
                  )
                : const SizedBox(width: 260, height: 260),
          ),
        ),

        const SizedBox(height: 28),

        // Compte à rebours
        _buildCountdown(isExpiringSoon),

        const SizedBox(height: 16),

        // Bouton renouveler manuellement
        TextButton.icon(
          onPressed: () {
            _refreshTimer?.cancel();
            _startQRCycle();
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Renouveler maintenant'),
          style: TextButton.styleFrom(foregroundColor: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildCountdown(bool isExpiringSoon) {
    return Column(
      children: [
        // Barre de progression
        SizedBox(
          width: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _secondsLeft / 30,
              backgroundColor: Colors.white.withOpacity(0.1),
              color: isExpiringSoon ? AppTheme.error : AppTheme.primary,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpiringSoon ? Icons.warning_amber : Icons.timer_outlined,
              color: isExpiringSoon ? AppTheme.error : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isExpiringSoon
                  ? 'Expiration dans $_secondsLeft sec...'
                  : 'Valable encore $_secondsLeft secondes',
              style: TextStyle(
                color: isExpiringSoon ? AppTheme.error : Colors.white54,
                fontSize: 13,
                fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Erreur réseau ─────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: AppTheme.error, size: 60),
          const SizedBox(height: 20),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _loadGeofences,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ─── Pas de zone configurée ────────────────────────────
  Widget _buildNoGeofence() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, color: Colors.white38, size: 60),
          const SizedBox(height: 20),
          const Text('Aucune zone configurée.',
              style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Connectez-vous en tant qu\'admin pour ajouter une zone.',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  // ─── Barre inférieure ──────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('© CONATEL ${DateTime.now().year} · Système de Présence',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: Icon(Icons.admin_panel_settings_outlined,
                color: Colors.white.withOpacity(0.3), size: 16),
            label: Text('Admin', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
