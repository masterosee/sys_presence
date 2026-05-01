// lib/core/constants.dart

class AppConstants {
  // À changer selon l'environnement
  static const String apiBaseUrl = 'http://192.168.1.100:8000/api/v1';

  // Storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyUserData = 'user_data';
  static const String keyEmployeeId = 'employee_id';

  // QR Code
  static const int qrRefreshSeconds = 30;

  // Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Statuts
  static const String statusPresent = 'present';
  static const String statusLate = 'late';
  static const String statusAbsent = 'absent';
  static const String statusRemote = 'remote';
  static const String statusOnLeave = 'on_leave';
}
