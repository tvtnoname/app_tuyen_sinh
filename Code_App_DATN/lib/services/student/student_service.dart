import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StudentService {
  final String baseUrl;

  StudentService({this.baseUrl = 'http://192.168.1.218:8080/api/student'});

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Lấy thông báo cho học sinh

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/notification');
      
      debugPrint('StudentService.getNotifications: $uri');
      
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        
        if (body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
        return [];
      } else {
        debugPrint('Failed to load notifications: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('StudentService.getNotifications error: $e');
      return [];
    }
  }

  /// Lấy thông tin giáo viên theo teacherId
  Future<Map<String, dynamic>?> getTeacherInfo(int teacherId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/teacher/$teacherId');
      
      debugPrint('StudentService.getTeacherInfo: $uri');
      
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        
        if (body['data'] is Map) {
          return Map<String, dynamic>.from(body['data']);
        }
        return null;
      } else {
        debugPrint('Failed to load teacher info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('StudentService.getTeacherInfo error: $e');
      return null;
    }
  }

  /// Đánh dấu thông báo là đã đọc
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/notification/$notificationId/read');
      
      final response = await http.patch(
        uri,
        headers: headers,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // Error marking notification as read
      return false;
    }
  }
}
