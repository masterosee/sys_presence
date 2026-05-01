/// Dashboard RH - Vue d'ensemble des présences
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RHDashboardScreen extends ConsumerStatefulWidget {
  const RHDashboardScreen({super.key});

  @override
  ConsumerState<RHDashboardScreen> createState() => _RHDashboardScreenState();
}

class _RHDashboardScreenState extends ConsumerState<RHDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _todayList = [];
  bool _loading = true;
  String _filter = 'all'; // all, present, late, absent

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getDashboardStats(),
        api.getTodayAll(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _todayList = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'all') return _todayList;
    return _todayList.where((r) {
      if (_filter == 'absent') return r['status'] == 'absent' || r['check_in'] == null;
      return r['status'] == _filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildKPICards()),
                    SliverToBoxAdapter(child: _buildFilterBar()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Présences du jour (${_filtered.length})',
                          style: AppTheme.heading2,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildEmployeeRow(_filtered[i]),
                        childCount: _filtered.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── En-tête ──────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    final months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    final dateStr = '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard RH', style: AppTheme.heading1),
                const SizedBox(height: 4),
                Text(dateStr, style: AppTheme.textSecondary),
              ],
            ),
          ),
          // Bouton export
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.download_outlined, color: AppTheme.primary),
              onPressed: _exportReport,
              tooltip: 'Exporter rapport',
            ),
          ),
          const SizedBox(width: 8),
          // Bouton ajouter employé
          Container(
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.person_add_outlined, color: AppTheme.success),
              onPressed: () => context.go('/employees/add'),
              tooltip: 'Ajouter employé',
            ),
          ),
        ],
      ),
    );
  }

  // ─── KPI Cards ────────────────────────────────────────
  Widget _buildKPICards() {
    final total    = _stats?['total_employees'] ?? 0;
    final present  = _stats?['present_today']   ?? 0;
    final late     = _stats?['late_today']       ?? 0;
    final absent   = _stats?['absent_today']     ?? 0;
    final remote   = _stats?['remote_today']     ?? 0;
    final rate     = total > 0 ? (present * 100 / total).toStringAsFixed(0) : '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Taux de présence global
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Taux de présence',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('$rate%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 42,
                              fontWeight: FontWeight.bold)),
                      Text('$present présents sur $total employés',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                // Mini graphique circulaire
                SizedBox(
                  width: 80, height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total > 0 ? present / total : 0,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        color: Colors.white,
                      ),
                      Icon(Icons.people_outline, color: Colors.white.withOpacity(0.8), size: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4 petites cartes
          Row(
            children: [
              _KPICard(value: '$present', label: 'Présents',   icon: Icons.check_circle_outline, color: AppTheme.success),
              const SizedBox(width: 10),
              _KPICard(value: '$late',    label: 'Retards',    icon: Icons.access_time,           color: AppTheme.warning),
              const SizedBox(width: 10),
              _KPICard(value: '$absent',  label: 'Absents',    icon: Icons.cancel_outlined,       color: AppTheme.error),
              const SizedBox(width: 10),
              _KPICard(value: '$remote',  label: 'Distance',   icon: Icons.home_work_outlined,    color: AppTheme.secondary),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Filtres ──────────────────────────────────────────
  Widget _buildFilterBar() {
    final filters = [
      ('all', 'Tous', Colors.grey),
      ('present', 'Présents', AppTheme.success),
      ('late', 'Retards', AppTheme.warning),
      ('absent', 'Absents', AppTheme.error),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = f.$1),
              selectedColor: f.$3.withOpacity(0.15),
              checkmarkColor: f.$3,
              labelStyle: TextStyle(
                color: isSelected ? f.$3 : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? f.$3 : Colors.grey.shade300,
              ),
              backgroundColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Ligne employé ────────────────────────────────────
  Widget _buildEmployeeRow(Map<String, dynamic> record) {
    final name       = record['employee_name'] ?? 'Inconnu';
    final code       = record['employee_code'] ?? '';
    final dept       = record['department']    ?? '--';
    final status     = record['status']        ?? 'absent';
    final checkIn    = record['check_in'];
    final checkOut   = record['check_out'];
    final isLate     = record['is_late'] ?? false;
    final lateMin    = record['late_minutes'] ?? 0;
    final photoUrl   = record['photo_url'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'present':
        statusColor = AppTheme.success; statusLabel = 'Présent'; statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = AppTheme.warning; statusLabel = 'En retard'; statusIcon = Icons.access_time;
        break;
      case 'remote':
        statusColor = AppTheme.secondary; statusLabel = 'À distance'; statusIcon = Icons.home_work;
        break;
      default:
        statusColor = AppTheme.error; statusLabel = 'Absent'; statusIcon = Icons.cancel;
    }

    String formatTime(String? iso) {
      if (iso == null) return '--:--';
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withOpacity(0.1),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 12),

          // Nom + département
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('$code · $dept', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                if (isLate)
                  Text('$lateMin min de retard',
                      style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Heures
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.login, size: 12, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Text(formatTime(checkIn),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.logout, size: 12, color: AppTheme.error),
                  const SizedBox(width: 4),
                  Text(formatTime(checkOut),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Badge statut
          Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(height: 2),
              Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📄 Export en cours... (fonctionnalité à implémenter)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Widget KPI Card ──────────────────────────────────────────
class _KPICard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
