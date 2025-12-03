import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class GradeService {
  final AuthService _authService;

  GradeService({AuthService? authService}) : _authService = authService ?? AuthService();

  // Lấy base URL từ authService.baseUrl

  String _apiBase() {
    var apiBase = _authService.baseUrl;
    if (apiBase.endsWith('/api/auth')) {
      apiBase = apiBase.substring(0, apiBase.length - '/api/auth'.length);
    }
    return apiBase;
  }

  /// Lấy điểm số cho tất cả học sinh trong một lớp

  Future<List<Map<String, dynamic>>> getClassGrades(int classId) async {
    try {
      final token = await _authService.getToken();
      // Sử dụng đúng endpoint: /api/teacher/grade?classId=...

      final uri = Uri.parse('${_apiBase()}/api/teacher/grade?classId=$classId');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final dynamic body = jsonDecode(resp.body);
        
        // Xử lý các định dạng phản hồi khác nhau

        if (body is List) {
          return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (body is Map && body['data'] is List) {
          return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        
        return [];
      } else {
        throw Exception('Failed to load grades: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('GradeService.getClassGrades error: $e');
      rethrow;
    }
  }

  /// Lấy điểm số cho một học sinh cụ thể trong lớp

  Future<Map<String, dynamic>?> getStudentGrades(int studentId, int classId) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/grades/$studentId/$classId');

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
        } else {
          return Map<String, dynamic>.from(body);
        }
      } else {
        throw Exception('Failed to load student grades: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('GradeService.getStudentGrades error: $e');
      rethrow;
    }
  }

  /// Cập nhật điểm số cho một học sinh
  /// 
  /// [studentId]: ID người dùng là học sinh
  /// [classId]: ID lớp học
  /// [grades]: Map chứa dữ liệu điểm (score_1, score_2, score_3, final_score)

  Future<Map<String, dynamic>> updateGrades({
    required int studentId,
    required int classId,
    required Map<String, dynamic> grades,
  }) async {
    try {
      final token = await _authService.getToken();
      // Sử dụng đúng endpoint: /api/teacher/grade (không có 's')

      final uri = Uri.parse('${_apiBase()}/api/teacher/grade');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'studentId': studentId,
        'classId': classId,
        ...grades,
      });

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> responseBody = jsonDecode(resp.body) as Map<String, dynamic>;

        if (responseBody['data'] is Map) {
          return Map<String, dynamic>.from(responseBody['data'] as Map);
        } else {
          return Map<String, dynamic>.from(responseBody);
        }
      } else {
        try {
          final Map<String, dynamic> errorBody = jsonDecode(resp.body);
          final msg = errorBody['message'] ?? errorBody['msg'] ?? errorBody['error'] ?? resp.body;
          throw Exception(msg);
        } catch (_) {
          throw Exception('Failed to update grades: ${resp.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('GradeService.updateGrades error: $e');
      rethrow;
    }
  }

  /// Cập nhật điểm số hàng loạt cho nhiều học sinh
  Future<bool> batchUpdateGrades({
    required int classId,
    required List<Map<String, dynamic>> studentGrades,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${_apiBase()}/api/teacher/grades/batch');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        'classId': classId,
        'grades': studentGrades,
      });

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 15));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        throw Exception('Failed to batch update grades: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('GradeService.batchUpdateGrades error: $e');
      rethrow;
    }
  }
}
