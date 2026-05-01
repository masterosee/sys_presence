// lib/screens/history/history_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/attendance.dart' show Attendance;
import '../../services/attendance_service.dart' show AttendanceService;
import '../../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AttendanceService _service = AttendanceService();

  List<Attendance> _history = <Attendance>[];
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final data = await _service.getHistory(
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );
    if (mounted)
      setState(() {
        _history = data;
        _loading = false;
      });
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
    _loadHistory();
  }

  void _nextMonth() {
    if (_selectedMonth.month == DateTime.now().month &&
        _selectedMonth.year == DateTime.now().year) return;
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });
    _loadHistory();
  }

  // Stats du mois
  int get _presentCount => _history
      .where((a) => a.status == 'present' || a.status == 'remote')
      .length;
  int get _lateCount => _history.where((a) => a.isLate).length;
  int get _absentCount => _history.where((a) => a.status == 'absent').length;
  int get _totalMinutes =>
      _history.fold<int>(0, (sum, a) => sum + (a.workDuration ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMonthSelector(),
            _buildStatsRow(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.blue, strokeWidth: 2))
                  : _history.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Text('Historique',
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                letterSpacing: -0.5,
              )),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final label = DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.month == DateTime.now().month &&
        _selectedMonth.year == DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _prevMonth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.text, size: 20),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          GestureDetector(
            onTap: isCurrentMonth ? null : _nextMonth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: isCurrentMonth ? AppColors.border : AppColors.text,
                  size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalH = _totalMinutes ~/ 60;
    final totalM = _totalMinutes % 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statChip('$_presentCount', 'Présents', AppColors.green),
          const SizedBox(width: 8),
          _statChip('$_lateCount', 'Retards', AppColors.amber),
          const SizedBox(width: 8),
          _statChip('$_absentCount', 'Absents', AppColors.red),
          const SizedBox(width: 8),
          _statChip('${totalH}h${totalM.toString().padLeft(2, '0')}', 'Total',
              AppColors.blue),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
            Text(label,
                style:
                    GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: _history.length,
      itemBuilder: (context, i) => _buildItem(_history[i]),
    );
  }

  Widget _buildItem(Attendance a) {
    final date = DateTime.tryParse(a.date);
    final color = statusColor(a.status);
    final label = statusLabel(a.status);
    final dateStr =
        date != null ? DateFormat('EEE d MMM', 'fr_FR').format(date) : a.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Date
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                date != null ? '${date.day}' : '--',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(label,
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _timeInfo(Icons.login_rounded, a.checkInTime),
                    const SizedBox(width: 16),
                    _timeInfo(Icons.logout_rounded, a.checkOutTime),
                    const Spacer(),
                    if (a.workDuration != null)
                      Text(
                        a.workDurationFormatted,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blue,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeInfo(IconData icon, String time) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(time,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Aucun pointage ce mois',
              style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.muted)),
        ],
      ),
    );
  }
}
