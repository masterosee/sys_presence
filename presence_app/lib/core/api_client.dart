// lib/core/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String _baseUrl = 'http://192.168.148.211:8000/api/v1';
  // ↑ Change cette IP par l'IP de ton serveur FastAPI

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Intercepteur : ajoute le token JWT automatiquement
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Token expiré → déconnexion automatique
          if (error.response?.statusCode == 401) {
            await _storage.deleteAll();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // ─── Auth ────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    // Sauvegarder le token
    await _storage.write(key: 'access_token', value: res.data['access_token']);
    await _storage.write(key: 'user_data', value: res.data.toString());
    return res.data;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  // ─── Pointages ───────────────────────────────────────────

  Future<Map<String, dynamic>> checkinQR({
    required String qrToken,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _dio.post(
      '/attendances/checkin/qr',
      data: {'qr_token': qrToken, 'latitude': latitude, 'longitude': longitude},
    );
    return res.data;
  }

  Future<Map<String, dynamic>> checkout({
    String method = 'qr_code',
    String? qrToken,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _dio.post(
      '/attendances/checkout',
      data: {
        'method': method,
        'qr_token': qrToken,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return res.data;
  }

  Future<Map<String, dynamic>> getTodayAttendance() async {
    final res = await _dio.get('/attendances/today');
    return res.data;
  }

  Future<List<dynamic>> getHistory({int? month, int? year}) async {
    final res = await _dio.get(
      '/attendances/history',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    return res.data;
  }

  // ─── QR Code ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getActiveQR(String geofenceId) async {
    final res = await _dio.get('/qr/active/$geofenceId');
    return res.data;
  }

  // ─── Employé ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await _dio.get('/employees/me');
    return res.data;
  }

  // ─── Congés ──────────────────────────────────────────────

  Future<List<dynamic>> getLeaveRequests() async {
    final res = await _dio.get('/leaves/my');
    return res.data;
  }

  Future<Map<String, dynamic>> createLeaveRequest({
    required String leaveTypeId,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    final res = await _dio.post(
      '/leaves',
      data: {
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
      },
    );
    return res.data;
  }
}
