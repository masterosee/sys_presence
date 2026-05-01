// lib/models/attendance.dart

class Attendance {
  final String id;
  final String employeeId;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final String? checkInMethod;
  final String? checkOutMethod;
  final String status;
  final bool isLate;
  final int lateMinutes;
  final int? workDuration;
  final String message;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.checkInMethod,
    this.checkOutMethod,
    required this.status,
    required this.isLate,
    required this.lateMinutes,
    this.workDuration,
    this.message = '',
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      date: json['date'] ?? '',
      checkIn: json['check_in'],
      checkOut: json['check_out'],
      checkInMethod: json['check_in_method'],
      checkOutMethod: json['check_out_method'],
      status: json['status'] ?? 'absent',
      isLate: json['is_late'] ?? false,
      lateMinutes: json['late_minutes'] ?? 0,
      workDuration: json['work_duration'],
      message: json['message'] ?? '',
    );
  }

  // Heure d'arrivée formatée ex: "08:02"
  String get checkInTime {
    if (checkIn == null) return '--:--';
    final dt = DateTime.tryParse(checkIn!);
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  // Heure de départ formatée
  String get checkOutTime {
    if (checkOut == null) return '--:--';
    final dt = DateTime.tryParse(checkOut!);
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  // Durée travaillée formatée ex: "7h30"
  String get workDurationFormatted {
    if (workDuration == null) return '--';
    final h = workDuration! ~/ 60;
    final m = workDuration! % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  // Déjà pointé l'entrée ?
  bool get hasCheckedIn => checkIn != null;

  // Déjà pointé la sortie ?
  bool get hasCheckedOut => checkOut != null;
}
