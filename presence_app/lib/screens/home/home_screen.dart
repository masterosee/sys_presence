// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/attendance.dart' show Attendance;
import '../../services/attendance_service.dart' show AttendanceService;
import '../../theme/app_theme.dart';
import '../qr/qr_scanner_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  int _currentIndex = 0;
  Attendance? _todayAttendance;
  Map<String, dynamic> _weekStats = {};
  bool _loading = true;

  // Données employé (à remplacer par un Provider plus tard)
  final String _employeeName = 'Ossiny Bien-Aimé';
  final String _employeeInitials = 'OB';
  final String _employeePost = 'Ingénieur Réseau';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final today = await _attendanceService.getTodayAttendance();
      final stats = await _attendanceService.getWeekStats();
      if (mounted) {
        setState(() {
          _todayAttendance = today;
          _weekStats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          const HistoryScreen(),
          const QrScannerScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── HOME TAB ────────────────────────────────────────────

  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.blue,
        backgroundColor: AppColors.surface,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildGreeting(),
            const SizedBox(height: 20),
            _loading ? _buildLoadingSkeleton() : _buildStatusCard(),
            const SizedBox(height: 16),
            _buildQrButton(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildWeekSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Avatar
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.blue, AppColors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              _employeeInitials,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Logo CONATEL
        Text(
          'CONATEL',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            letterSpacing: 2,
          ),
        ),

        // Notification
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.notifications_outlined,
                    color: AppColors.muted, size: 20),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── GREETING ────────────────────────────────────────────

  Widget _buildGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 12)
      greeting = 'Bonjour,';
    else if (hour < 18)
      greeting = 'Bon après-midi,';
    else
      greeting = 'Bonsoir,';

    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting,
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(_employeeName,
            style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STATUS CARD ─────────────────────────────────────────

  Widget _buildStatusCard() {
    final att = _todayAttendance;
    final status = att?.status ?? 'not_checked_in';
    final color = att != null ? statusColor(status) : AppColors.muted;
    final label = att != null ? statusLabel(status) : 'Non pointé';

    // Progression journée (8h = 480 min)
    double progress = 0;
    if (att?.workDuration != null) {
      progress = (att!.workDuration! / 480).clamp(0.0, 1.0);
    } else if (att?.hasCheckedIn == true) {
      final checkInDt = DateTime.tryParse(att!.checkIn!);
      if (checkInDt != null) {
        final elapsed = DateTime.now().difference(checkInDt).inMinutes;
        progress = (elapsed / 480).clamp(0.0, 1.0);
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pointage du jour',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.muted,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w500)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(label,
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Temps
          Row(
            children: [
              Expanded(
                  child: _timeBlock(
                      'Arrivée', att?.checkInTime ?? '--:--', AppColors.blue)),
              Expanded(
                  child: _timeBlock(
                      'Départ', att?.checkOutTime ?? '--:--', AppColors.muted)),
              Expanded(
                  child: _timeBlock('Travaillé',
                      att?.workDurationFormatted ?? '--', AppColors.green)),
            ],
          ),

          const SizedBox(height: 16),

          // Barre de progression
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progression journée',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted)),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.blue),
                ),
              ),
            ],
          ),

          // Retard si applicable
          if (att?.isLate == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppColors.amber, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'En retard de ${att!.lateMinutes} minutes',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.amber),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeBlock(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  // ─── QR BUTTON ───────────────────────────────────────────

  Widget _buildQrButton() {
    final hasCheckedIn = _todayAttendance?.hasCheckedIn ?? false;
    final hasCheckedOut = _todayAttendance?.hasCheckedOut ?? false;

    String label;
    if (!hasCheckedIn)
      label = 'Scanner QR Code — Entrée';
    else if (!hasCheckedOut)
      label = 'Scanner QR Code — Sortie';
    else
      label = 'Pointage du jour terminé ✓';

    final bool disabled = hasCheckedOut;

    return GestureDetector(
      onTap: disabled
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrScannerScreen(
                    isCheckout: hasCheckedIn,
                  ),
                ),
              );
              _loadData();
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  colors: [AppColors.blue, AppColors.purple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: disabled ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(16),
          border: disabled ? Border.all(color: AppColors.border) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              disabled
                  ? Icons.check_circle_outline_rounded
                  : Icons.qr_code_scanner_rounded,
              color: disabled ? AppColors.green : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: disabled ? AppColors.green : Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK ACTIONS ───────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions rapides',
            style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _actionCard(
              icon: Icons.calendar_month_rounded,
              iconColor: AppColors.blue,
              iconBg: AppColors.blue.withOpacity(0.15),
              title: 'Historique',
              subtitle: 'Ce mois',
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _actionCard(
              icon: Icons.beach_access_rounded,
              iconColor: AppColors.green,
              iconBg: AppColors.green.withOpacity(0.15),
              title: 'Congés',
              subtitle: '12 jours restants',
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.group_rounded,
              iconColor: AppColors.purple,
              iconBg: AppColors.purple.withOpacity(0.15),
              title: 'Équipe',
              subtitle: 'Présences',
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.bar_chart_rounded,
              iconColor: AppColors.amber,
              iconBg: AppColors.amber.withOpacity(0.15),
              title: 'Rapports',
              subtitle: DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now()),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const Spacer(),
            Text(title,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text)),
            Text(subtitle,
                style:
                    GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // ─── WEEK SECTION ────────────────────────────────────────

  Widget _buildWeekSection() {
    final weekDays = (_weekStats['week_days'] as List?) ?? [];
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cette semaine',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Text('Voir tout',
                  style:
                      GoogleFonts.dmSans(fontSize: 12, color: AppColors.blue)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(5, (i) {
            if (i < weekDays.length) {
              final day = weekDays[i];
              final dayDate = day['date'] as DateTime;
              final att = day['attendance'] as Attendance?;
              final isToday =
                  dayDate.day == today.day && dayDate.month == today.month;
              return Expanded(
                child: _dayPill(
                  name: day['name'] as String,
                  status: att?.status,
                  time: att?.checkInTime,
                  isToday: isToday,
                ),
              );
            }
            return const Expanded(child: SizedBox());
          }),
        ),
      ],
    );
  }

  Widget _dayPill({
    required String name,
    String? status,
    String? time,
    bool isToday = false,
  }) {
    Color dotColor;
    if (isToday && status == null) {
      dotColor = AppColors.blue;
    } else if (status == null) {
      dotColor = AppColors.border;
    } else {
      dotColor = statusColor(status);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? AppColors.blue : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(name,
              style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: isToday ? AppColors.blue : AppColors.muted)),
          const SizedBox(height: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isToday && status == null ? 'En cours' : (time ?? '--'),
            style: GoogleFonts.dmSans(
              fontSize: 9,
              color: isToday ? AppColors.blue : AppColors.muted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── LOADING SKELETON ────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.blue,
          strokeWidth: 2,
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ──────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.dmSans(fontSize: 10),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scanner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
