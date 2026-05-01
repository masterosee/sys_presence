/// Service API complet - Communication avec le backend FastAPI
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String kBaseUrl = 'http://192.168.148.211:8000/api/v1';
const _storage = FlutterSecureStorage();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        await _storage.deleteAll();
      }
      return handler.next(error);
    },
  ));
  return dio;
});

class LoginResponse {
  final String accessToken, refreshToken, role, employeeId, fullName, employeeCode;
  LoginResponse({
    required this.accessToken, required this.refreshToken, required this.role,
    required this.employeeId, required this.fullName, required this.employeeCode,
  });
  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
    accessToken: j['access_token'], refreshToken: j['refresh_token'],
    role: j['role'], employeeId: j['employee_id'],
    fullName: j['full_name'], employeeCode: j['employee_code'],
  );
}

class AttendanceModel {
  final String id, date, status, message;
  final String? checkIn, checkOut, checkInMethod;
  final bool isLate;
  final int lateMinutes;
  final int? workDuration;

  AttendanceModel({
    required this.id, required this.date, required this.status,
    required this.message, this.checkIn, this.checkOut, this.checkInMethod,
    required this.isLate, required this.lateMinutes, this.workDuration,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> j) => AttendanceModel(
    id: j['id'], date: j['date'], status: j['status'], message: j['message'] ?? '',
    checkIn: j['check_in'], checkOut: j['check_out'], checkInMethod: j['check_in_method'],
    isLate: j['is_late'] ?? false, lateMinutes: j['late_minutes'] ?? 0,
    workDuration: j['work_duration'],
  );

  String _fmt(String? iso) {
    if (iso == null) return '--:--';
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  String get formattedCheckIn  => _fmt(checkIn);
  String get formattedCheckOut => _fmt(checkOut);
  String get formattedDuration {
    if (workDuration == null) return '--';
    return '${workDuration! ~/ 60}h${(workDuration! % 60).toString().padLeft(2,'0')}';
  }
}

class EmployeeModel {
  final String id, employeeCode, firstName, lastName, fullName, email;
  final String? phone, photoUrl, hireDate, contractType;
  final Map<String, dynamic>? department, position, statsThisMonth;
  final bool isRemote, isActive;

  EmployeeModel({
    required this.id, required this.employeeCode, required this.firstName,
    required this.lastName, required this.fullName, required this.email,
    this.phone, this.photoUrl, this.hireDate, this.contractType,
    this.department, this.position, this.statsThisMonth,
    required this.isRemote, required this.isActive,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> j) => EmployeeModel(
    id: j['id'], employeeCode: j['employee_code'],
    firstName: j['first_name'], lastName: j['last_name'],
    fullName: j['full_name'], email: j['email'],
    phone: j['phone'], photoUrl: j['photo_url'],
    hireDate: j['hire_date'], contractType: j['contract_type'],
    department: j['department'], position: j['position'],
    statsThisMonth: j['stats_this_month'],
    isRemote: j['is_remote'] ?? false, isActive: j['is_active'] ?? true,
  );
}

class LeaveRequestModel {
  final String id, leaveTypeName, leaveTypeColor, startDate, endDate, status, createdAt;
  final int totalDays;
  final String? reason, reviewComment;

  LeaveRequestModel({
    required this.id, required this.leaveTypeName, required this.leaveTypeColor,
    required this.startDate, required this.endDate, required this.totalDays,
    this.reason, required this.status, this.reviewComment, required this.createdAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> j) => LeaveRequestModel(
    id: j['id'], leaveTypeName: j['leave_type_name'] ?? '',
    leaveTypeColor: j['leave_type_color'] ?? '#6366F1',
    startDate: j['start_date'], endDate: j['end_date'],
    totalDays: j['total_days'], reason: j['reason'],
    status: j['status'], reviewComment: j['review_comment'],
    createdAt: j['created_at'],
  );
}

class ApiService {
  final Dio _dio;
  ApiService(this._dio);

  Future<LoginResponse> login(String username, String password) async {
    final r = await _dio.post('/auth/login',
      data: {'username': username, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = LoginResponse.fromJson(r.data);
    await _storage.write(key: 'access_token',  value: data.accessToken);
    await _storage.write(key: 'refresh_token', value: data.refreshToken);
    await _storage.write(key: 'role',          value: data.role);
    await _storage.write(key: 'employee_id',   value: data.employeeId);
    await _storage.write(key: 'full_name',     value: data.fullName);
    await _storage.write(key: 'employee_code', value: data.employeeCode);
    return data;
  }

  Future<void> logout() async => await _storage.deleteAll();
  Future<bool> isLoggedIn() async => await _storage.read(key: 'access_token') != null;
  Future<String?> getFullName()     => _storage.read(key: 'full_name');
  Future<String?> getRole()         => _storage.read(key: 'role');
  Future<String?> getEmployeeId()   => _storage.read(key: 'employee_id');
  Future<String?> getEmployeeCode() => _storage.read(key: 'employee_code');

  Future<Map<String, dynamic>> getMe() async {
    final r = await _dio.get('/auth/me');
    return r.data;
  }

  Future<void> changePassword(String oldPwd, String newPwd) async {
    await _dio.post('/auth/change-password',
        data: {'old_password': oldPwd, 'new_password': newPwd});
  }

  Future<AttendanceModel> checkinQR({
    required String qrToken, double? latitude, double? longitude,
  }) async {
    final r = await _dio.post('/attendances/checkin/qr', data: {
      'qr_token': qrToken,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return AttendanceModel.fromJson(r.data);
  }

  Future<AttendanceModel> checkinGPS({
    required double latitude, required double longitude,
  }) async {
    final r = await _dio.post('/attendances/checkin/gps',
        data: {'latitude': latitude, 'longitude': longitude});
    return AttendanceModel.fromJson(r.data);
  }

  Future<AttendanceModel> checkinPIN({
    required String employeeCode, required String pin,
    double? latitude, double? longitude,
  }) async {
    final r = await _dio.post('/attendances/checkin/pin', data: {
      'employee_code': employeeCode, 'pin': pin,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return AttendanceModel.fromJson(r.data);
  }

  Future<AttendanceModel> checkout({
    String method = 'gps', String? qrToken,
    double? latitude, double? longitude,
  }) async {
    final r = await _dio.post('/attendances/checkout', data: {
      'method': method,
      if (qrToken != null) 'qr_token': qrToken,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return AttendanceModel.fromJson(r.data);
  }

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final r = await _dio.get('/attendances/today');
    return r.data;
  }

  Future<List<AttendanceModel>> getHistory({int? month, int? year}) async {
    final r = await _dio.get('/attendances/history', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return (r.data as List).map((e) => AttendanceModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> generateQR(String geofenceId) async {
    final r = await _dio.get('/qr/generate/$geofenceId');
    return r.data;
  }

  Future<List<dynamic>> getGeofences() async {
    final r = await _dio.get('/qr/geofences');
    return r.data;
  }

  Future<Map<String, dynamic>> createGeofence({
    required String name, required double latitude, required double longitude,
    int radiusMeters = 200, String? description,
  }) async {
    final r = await _dio.post('/qr/geofences', data: {
      'name': name, 'latitude': latitude, 'longitude': longitude,
      'radius_meters': radiusMeters,
      if (description != null) 'description': description,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> listEmployees({
    String? search, String? departmentId, int page = 1, int limit = 20,
  }) async {
    final r = await _dio.get('/employees/', queryParameters: {
      if (search != null) 'search': search,
      if (departmentId != null) 'department_id': departmentId,
      'page': page, 'limit': limit,
    });
    return r.data;
  }

  Future<EmployeeModel> getEmployee(String employeeId) async {
    final r = await _dio.get('/employees/$employeeId');
    return EmployeeModel.fromJson(r.data);
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final r = await _dio.post('/employees/', data: data);
    return r.data;
  }

  Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> data) async {
    final r = await _dio.patch('/employees/$id', data: data);
    return r.data;
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final r = await _dio.get('/employees/stats/dashboard');
    return r.data;
  }

  Future<List<dynamic>> getTodayAll() async {
    final r = await _dio.get('/employees/stats/today-all');
    return r.data;
  }

  Future<List<LeaveRequestModel>> getMyLeaves() async {
    final r = await _dio.get('/leaves/my');
    return (r.data as List).map((e) => LeaveRequestModel.fromJson(e)).toList();
  }

  Future<List<dynamic>> getLeaveTypes() async {
    final r = await _dio.get('/leaves/types');
    return r.data;
  }

  Future<Map<String, dynamic>> requestLeave({
    required String leaveTypeId, required String startDate,
    required String endDate, String? reason,
  }) async {
    final r = await _dio.post('/leaves/request', data: {
      'leave_type_id': leaveTypeId, 'start_date': startDate,
      'end_date': endDate, if (reason != null) 'reason': reason,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> reviewLeave({
    required String leaveId, required String status, String? comment,
  }) async {
    final r = await _dio.patch('/leaves/$leaveId/review', data: {
      'status': status, if (comment != null) 'comment': comment,
    });
    return r.data;
  }

  Future<List<dynamic>> getPendingLeaves() async {
    final r = await _dio.get('/leaves/pending');
    return r.data;
  }

  Future<Map<String, dynamic>> getMonthlyReport({
    int? month, int? year, String? departmentId,
  }) async {
    final now = DateTime.now();
    final r = await _dio.get('/reports/monthly', queryParameters: {
      'month': month ?? now.month, 'year': year ?? now.year,
      if (departmentId != null) 'department_id': departmentId,
    });
    return r.data;
  }

  Future<List<dynamic>> getDepartments() async {
    final r = await _dio.get('/departments/');
    return r.data;
  }
}

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.read(dioProvider)),
);
