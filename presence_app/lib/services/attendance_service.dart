// lib/services/attendance_service.dart

import '../core/api_client.dart';
import '../models/attendance.dart';

class AttendanceService {
  final ApiClient _api = ApiClient();

  // ─── Pointage du jour ────────────────────────────────────

  Future<Attendance?> getTodayAttendance() async {
    try {
      final data = await _api.getTodayAttendance();
      if (data['status'] == 'not_checked_in') return null;
      return Attendance.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  // ─── Historique du mois ──────────────────────────────────

  Future<List<Attendance>> getHistory({int? month, int? year}) async {
    try {
      final data = await _api.getHistory(month: month, year: year);
      return data.map((e) => Attendance.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Pointage entrée via QR ──────────────────────────────

  Future<Attendance> checkinQR({
    required String qrToken,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _api.checkinQR(
      qrToken: qrToken,
      latitude: latitude,
      longitude: longitude,
    );
    return Attendance.fromJson(data);
  }

  // ─── Pointage sortie ─────────────────────────────────────

  Future<Attendance> checkout({
    String method = 'qr_code',
    String? qrToken,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _api.checkout(
      method: method,
      qrToken: qrToken,
      latitude: latitude,
      longitude: longitude,
    );
    return Attendance.fromJson(data);
  }

  // ─── Stats semaine ───────────────────────────────────────

  Future<Map<String, dynamic>> getWeekStats() async {
    try {
      final now = DateTime.now();
      final history = await getHistory(month: now.month, year: now.year);

      // Filtrer les 5 derniers jours ouvrables
      final today = DateTime.now();
      final weekStart = today.subtract(Duration(days: today.weekday - 1));

      final weekDays = List.generate(5, (i) {
        final day = weekStart.add(Duration(days: i));
        return {
          'date': day,
          'name': _dayName(day.weekday),
          'attendance': history.where((a) {
            final aDate = DateTime.tryParse(a.date);
            return aDate != null &&
                aDate.day == day.day &&
                aDate.month == day.month;
          }).firstOrNull,
        };
      });

      final presentCount = history
          .where((a) => a.status == 'present' || a.status == 'remote')
          .length;
      final lateCount = history.where((a) => a.isLate).length;

      return {
        'week_days': weekDays,
        'present_count': presentCount,
        'late_count': lateCount,
        'absent_count': 5 - presentCount - lateCount,
      };
    } catch (e) {
      return {};
    }
  }

  String _dayName(int weekday) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return days[weekday - 1];
  }
}
