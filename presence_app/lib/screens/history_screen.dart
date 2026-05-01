/// Écran Historique - Liste des pointages du mois
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<AttendanceModel> _records = [];
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getHistory(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
      setState(() { _records = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ─── Stats du mois ───────────────────────────────────
  int get _totalPresent  => _records.where((r) => r.status != 'absent' && r.status != 'on_leave').length;
  int get _totalLate     => _records.where((r) => r.isLate).length;
  int get _totalAbsent   => _records.where((r) => r.status == 'absent').length;
  int get _totalMinutes  => _records.fold(0, (sum, r) => sum + (r.workDuration ?? 0));

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    final title = '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête + sélecteur mois
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Historique', style: AppTheme.heading1),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  IconButton(
                    onPressed: _selectedMonth.month == DateTime.now().month &&
                        _selectedMonth.year == DateTime.now().year
                        ? null
                        : () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // Statistiques rapides
            if (!_loading) _buildStats(),

            const SizedBox(height: 8),

            // Liste
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _records.length,
                            itemBuilder: (_, i) => _buildRow(_records[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _load();
  }

  // ─── Stats rapides ────────────────────────────────────
  Widget _buildStats() {
    final hours = _totalMinutes ~/ 60;
    final minutes = _totalMinutes % 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatChip(value: '$_totalPresent', label: 'Présences', color: AppTheme.success),
          const SizedBox(width: 8),
          _StatChip(value: '$_totalLate', label: 'Retards', color: AppTheme.warning),
          const SizedBox(width: 8),
          _StatChip(value: '$_totalAbsent', label: 'Absences', color: AppTheme.error),
          const SizedBox(width: 8),
          _StatChip(value: '${hours}h${minutes.toString().padLeft(2,'0')}', label: 'Total', color: AppTheme.primary),
        ],
      ),
    );
  }

  // ─── Ligne de pointage ────────────────────────────────
  Widget _buildRow(AttendanceModel record) {
    final dt = DateTime.parse(record.date);
    final days = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
    final months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    final dayName = days[dt.weekday - 1];
    final dateStr = '$dayName ${dt.day} ${months[dt.month - 1]}';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (record.status) {
      case 'present':
        statusColor = AppTheme.success; statusLabel = 'Présent'; statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = AppTheme.warning; statusLabel = 'En retard'; statusIcon = Icons.access_time;
        break;
      case 'absent':
        statusColor = AppTheme.error; statusLabel = 'Absent'; statusIcon = Icons.cancel;
        break;
      case 'remote':
        statusColor = AppTheme.secondary; statusLabel = 'À distance'; statusIcon = Icons.home_work;
        break;
      default:
        statusColor = Colors.grey; statusLabel = record.status; statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Row(
        children: [
          // Date
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${dt.day}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: statusColor)),
                Text(dayName, style: TextStyle(fontSize: 10, color: statusColor)),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _TimeTag(Icons.login, record.formattedCheckIn, Colors.green.shade700),
                    const SizedBox(width: 10),
                    _TimeTag(Icons.logout, record.formattedCheckOut, Colors.red.shade400),
                    if (record.workDuration != null) ...[
                      const SizedBox(width: 10),
                      _TimeTag(Icons.timer, record.formattedDuration, AppTheme.primary),
                    ],
                  ],
                ),
                if (record.isLate)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${record.lateMinutes} min de retard',
                        style: TextStyle(color: AppTheme.warning, fontSize: 11)),
                  ),
              ],
            ),
          ),

          // Statut
          Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(height: 2),
              Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucun pointage ce mois', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatChip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _TimeTag extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _TimeTag(this.icon, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
