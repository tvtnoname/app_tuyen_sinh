import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class AttendanceService {
  final AuthService _authService;

  AttendanceService({AuthService? authService}) : _authService = authService ?? AuthService();

  // Lấy base URL từ authService.baseUrl

  String _apiBase() {
    var apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }
    return apiBase;
  }

  /// Điểm danh cho một buổi học
  /// 
  /// [classId]: ID lớp học
  /// [date]: Ngày điểm danh (định dạng YYYY-MM-DD)
  /// [attendanceRecords]: Danh sách bản ghi điểm danh với studentId và trạng thái

  Future<bool> markAttendance({
    required int classId,
    required String date,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId,
        'date': date,
        'attendances': attendanceRecords,
      });

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        // Cố gắng phân tích thông báo lỗi

        try {
          final Map<String, dynamic> errorBody = jsonDecode(resp.body);
          final msg = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? resp.body;
          throw Exception(msg);
        } catch (_) {
          throw Exception('Failed to mark attendance: ${resp.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('AttendanceService.markAttendance error: $e');
      rethrow;
    }
  }

  /// Lấy thông tin điểm danh cho một lớp và ngày cụ thể

  Future<List<Map<String, dynamic>>> getAttendance({
    required int classId,
    required String date,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance/$classId/$date');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is List) {
          return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (body is List) {
          return (body as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        
        return [];
      } else {
        throw Exception('Failed to load attendance: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('AttendanceService.getAttendance error: $e');
      rethrow;
    }
  }

  /// Lấy lịch sử điểm danh của một học sinh trong lớp

  Future<List<Map<String, dynamic>>> getStudentAttendance({
    required int studentId,
    required int classId,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance/student/$studentId/$classId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is List) {
          return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (body is List) {
          return (body as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        
        return [];
      } else {
        throw Exception('Failed to load student attendance: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('AttendanceService.getStudentAttendance error: $e');
      rethrow;
    }
  }

  /// Lấy thống kê điểm danh cho một lớp

  Future<Map<String, dynamic>?> getAttendanceStats(int classId) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance/stats/$classId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        } else
          return Map<String, dynamic>.from(body);
      } else {
        throw Exception('Failed to load attendance stats: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('AttendanceService.getAttendanceStats error: $e');
      rethrow;
    }
  }
  /// Lấy toàn bộ lịch sử điểm danh của một lớp

  Future<List<Map<String, dynamic>>> getClassAttendanceHistory(int classId) async {
    try {
      final token = await _authService.getToken();
      // Thử sử dụng query parameter trước vì đây là chuẩn cho GET

      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance?classId=$classId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      // Lưu ý: Backend có thể yêu cầu body trong GET (không chuẩn), hoặc query params.
      // Thông thường backend Spring map query params vào object.

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(resp.body) as Map<String, dynamic>;
        
        if (body['data'] is List) {
          return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (body is List) {
          return (body as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        
        return [];
      } else {
        throw Exception('Failed to load attendance history: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('AttendanceService.getClassAttendanceHistory error: $e');
      rethrow;
    }
  }

  /// Điểm danh cho một học sinh lẻ

  Future<bool> markStudentAttendance({
    required int classId,
    required int scheduleId,
    required int studentId,
    required String date, // dd-MM-yyyy
    required String status,
    String? permissionReason,
    int lessonOrder = 1,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId,
        'scheduleId': scheduleId,
        'studentId': studentId,
        'attendanceDate': date,
        'lessonOrder': lessonOrder,
        'status': status,
        'permissionReason': permissionReason,
      });

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        // Cố gắng phân tích thông báo lỗi

        try {
          final Map<String, dynamic> errorBody = jsonDecode(resp.body);
          final msg = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? resp.body;
          throw Exception(msg);
        } catch (_) {
          throw Exception('Failed to mark student attendance: ${resp.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('AttendanceService.markStudentAttendance error: $e');
      rethrow;
    }
  }

  /// Cập nhật điểm danh cho một học sinh (PATCH)

  Future<bool> updateStudentAttendance({
    required int scheduleId,
    required int classId,
    required int studentId,
    required String date, // yyyy-MM-dd
    required String status,
    String? permissionReason,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance/$scheduleId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId,
        'scheduleId': scheduleId, // Thêm scheduleId vào body

        'studentId': studentId,
        'attendanceDate': date,
        'status': status,
        'permissionReason': permissionReason,
      });

      debugPrint('AttendanceService.updateStudentAttendance: $uri');
      debugPrint('Body: $body');

      final resp = await http.patch(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${resp.statusCode}');
      debugPrint('Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        try {
          final Map<String, dynamic> errorBody = jsonDecode(resp.body);
          final msg = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? resp.body;
          throw Exception(msg);
        } catch (_) {
          throw Exception('Failed to update student attendance: ${resp.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('AttendanceService.updateStudentAttendance error: $e');
      rethrow;
    }
  }

  /// Cập nhật bản ghi điểm danh theo attendanceId (PATCH)

  Future<bool> updateAttendanceRecord({
    required int attendanceId,
    required String status,
    String? permissionReason,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/attendance/$attendanceId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'status': status,
        'permissionReason': permissionReason,
      });

      debugPrint('AttendanceService.updateAttendanceRecord: $uri');
      debugPrint('Body: $body');

      final resp = await http.patch(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        try {
          final Map<String, dynamic> errorBody = jsonDecode(resp.body);
          final msg = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? resp.body;
          throw Exception(msg);
        } catch (_) {
          throw Exception('Failed to update attendance record: ${resp.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('AttendanceService.updateAttendanceRecord error: $e');
      rethrow;
    }
  }
}
